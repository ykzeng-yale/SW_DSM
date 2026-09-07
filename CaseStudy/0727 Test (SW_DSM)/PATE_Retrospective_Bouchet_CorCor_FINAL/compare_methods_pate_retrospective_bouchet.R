##############################################################################
# Comprehensive Comparison: Baseline vs Survey-Weighted Matching Methods
# For PATE under Retrospective Sampling - Final Corrected Version
# Addresses all simulation setup requirements
##############################################################################

# ============================================================================
# Setup and Libraries
# ============================================================================
cat("\n============================================================\n")
cat("Loading required packages...\n")
cat("============================================================\n")

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(nnet)
library(MatchIt)
library(parallel)
library(doParallel)
library(foreach)
library(boot)
library(marginaleffects)
library(dplyr)
library(tidyr)
library(purrr)
library(matrixStats)
library(Hmisc)

# Expit function - MUST be available globally
expit <- function(x) { exp(x) / (1 + exp(x)) }

# ============================================================================
# Retrospective Sampling Function (Treatment-dependent sampling)
# ============================================================================
retrospective_sample <- function(pop_data, n_sample = 5000) {
  N <- nrow(pop_data)
  
  # Coefficients for sample selection model (from original SW_PSW setup)
  c0 <- log(n_sample/N / (1 - n_sample/N))
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)  # Treatment affects sampling
  
  # Calculate sampling probabilities using ORIGINAL variable names
  formula_S <- c0 + delta_z_in_s * pop_data$z + 
    c1 * pop_data$x1 + c2 * pop_data$x2 + c3 * pop_data$x3 + 
    c4 * pop_data$x4 + c5 * pop_data$x5 + c6 * pop_data$x6
  
  prob_S <- expit(formula_S)
  pop_data$Prob <- prob_S
  
  # Sample units
  pop_data$S <- rbinom(N, 1, prob_S)
  sample_data <- pop_data[pop_data$S == 1, ]
  
  # Calculate survey weights
  sample_data$s.wt <- 1 / sample_data$Prob
  
  return(sample_data)
}

# ============================================================================
# Single Replicate Function
# ============================================================================
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M_values, B, alpha, scenarios) {
  
  # NO TIME LIMIT for individual methods - only overall job limit matters
  
  tryCatch({
    # Source dsmatch functions inside worker for PSOCK/FORK compatibility
    dsmatch_files <- c(
      "dsmatch-master/R/bisect.R",
      "dsmatch-master/R/is.lp.R",
      "dsmatch-master/R/is.ps.R", 
      "dsmatch-master/R/is.pg.R",
      "dsmatch-master/R/estforboot_dsATE.R",
      "dsmatch-master/R/estforboot_psATE.R",
      "dsmatch-master/R/estforboot_pgATE.R",
      "dsmatch-master/R/estforboot_covATE.R",
      "dsmatch-master/R/dsmatchATE.R"
    )
    
    for (file in dsmatch_files) {
      source(file)
    }
    
    # Source WDSM functions inside worker
    source("wdsm_method2_multinomial_bootstrap.R")
    source("wdsm_ci_functions.R")
    
    # Retrospective sampling using ORIGINAL variable names
    sample <- retrospective_sample(population, n_sample = n_sample)
    
    # Extract variables using ORIGINAL names
    Y <- sample$y  # Observed outcome
    X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
    A <- sample$z  # Treatment indicator
    w_raw <- sample$s.wt  # Survey weights
    
    # Normalized weights for PS Full (required for proper variance estimation)
    w_normalized <- w_raw * length(w_raw) / sum(w_raw)
    
    # Initialize results
    replicate_results <- list()
    
    # Loop over model specification scenarios
    for (scenario in scenarios) {
      
      # Determine model specifications based on scenario
      use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
      use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
      
      # Create covariate matrices for PS and PG models
      if (use_interaction_ps) {
        X_ps <- cbind(X, X[,1] * X[,2])
        colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        X_ps <- X
        colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      if (use_interaction_pg) {
        X_pg <- cbind(X, X[,1] * X[,2])
        colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        X_pg <- X
        colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      # Loop over M values
      for (M in M_values) {
        
        m_results <- list()
        
        # ============================================================
        # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING
        # ============================================================
        tryCatch({
          # DSM uses SEPARATE matrices for PS and PG
          dsm_result <- dsmatchATE(
            Y = Y,
            X = X_ps,  # PS model covariate matrix
            A = A,
            method = "dsm",
            model.ps = "logit",  # ALWAYS logit for PS
            model.pg = "linpred",  # Use linear predictors for PG
            lp.pg = X_pg,  # PG model covariate matrix (can differ from PS)
            cov.balance = FALSE,
            varest = TRUE,
            boots = B,
            mc = FALSE,
            ncpus = 1
          )
          
          m_results$dsm_unweighted <- list(
            estimate = dsm_result$est.ds,
            se = sqrt(dsm_result$bootvar[1,1]),
            ci_lower = dsm_result$est.ds - qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1]),
            ci_upper = dsm_result$est.ds + qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1])
          )
        }, error = function(e) {
          cat("DSM Error in rep", i.rep, "scenario", scenario, "M=", M, ":", e$message, "\n")
          m_results$dsm_unweighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
        })
        
        # ============================================================
        # METHOD 2: UNWEIGHTED PROGNOSTIC SCORE MATCHING
        # ============================================================
        tryCatch({
          pg_result <- dsmatchATE(
            Y = Y,
            X = X_pg,  # Use PG covariate matrix
            A = A,
            method = "pg",
            model.pg = "linpred",
            lp.pg = X_pg,
            cov.balance = FALSE,
            varest = TRUE,
            boots = B,
            mc = FALSE,
            ncpus = 1
          )
          
          m_results$pg_unweighted <- list(
            estimate = pg_result$est.pg,
            se = sqrt(pg_result$bootvar[1,1]),
            ci_lower = pg_result$est.pg - qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1]),
            ci_upper = pg_result$est.pg + qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1])
          )
        }, error = function(e) {
          cat("PG Error in rep", i.rep, "scenario", scenario, "M=", M, ":", e$message, "\n")
          m_results$pg_unweighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
        })
        
        # ============================================================
        # METHOD 3: UNWEIGHTED PROPENSITY SCORE MATCHING
        # ============================================================
        tryCatch({
          ps_result <- dsmatchATE(
            Y = Y,
            X = X_ps,  # Use PS covariate matrix
            A = A,
            method = "ps",
            model.ps = "logit",  # ALWAYS logit
            cov.balance = FALSE,
            varest = TRUE,
            boots = B,
            mc = FALSE,
            ncpus = 1
          )
          
          m_results$ps_unweighted <- list(
            estimate = ps_result$est.ps,
            se = sqrt(ps_result$bootvar[1,1]),
            ci_lower = ps_result$est.ps - qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1]),
            ci_upper = ps_result$est.ps + qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1])
          )
        }, error = function(e) {
          cat("PS Error in rep", i.rep, "scenario", scenario, "M=", M, ":", e$message, "\n")
          m_results$ps_unweighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
        })
        
        # ============================================================
        # METHOD 4: SURVEY-WEIGHTED PS FULL MATCHING
        # ============================================================
        tryCatch({
          # Create data frame for MatchIt with renamed variables
          match_data <- data.frame(
            Y = Y,
            A = A,
            X1 = X[,1], X2 = X[,2], X3 = X[,3],
            X4 = X[,4], X5 = X[,5], X6 = X[,6],
            sw = w_normalized  # Use normalized weights
          )
          
          # PS model formula based on scenario
          if (use_interaction_ps) {
            ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
          } else {
            ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6
          }
          
          # Full matching with survey weights
          m_out <- matchit(ps_formula, 
                          data = match_data, 
                          method = "full",
                          distance = "glm",
                          link = "logit",
                          estimand = "ATE",
                          s.weights = match_data$sw)
          
          # Outcome model - ALWAYS fully specified for bias correction
          # NOT a prognostic model - this is the outcome model for doubly robust estimation
          outcome_formula <- Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2)
          
          # Fit outcome model with matched data
          matched_data <- match.data(m_out, weights = "sw", drop.unmatched = FALSE)
          fit <- lm(outcome_formula, data = matched_data, weights = sw)
          
          # Average marginal effect for PATE
          comp <- avg_comparisons(fit, 
                                  variables = "A",
                                  vcov = ~subclass,
                                  wts = "sw",
                                  newdata = matched_data)
          
          m_results$ps_weighted <- list(
            estimate = comp$estimate,
            se = comp$std.error,
            ci_lower = comp$conf.low,
            ci_upper = comp$conf.high
          )
        }, error = function(e) {
          cat("SW-PS Error in rep", i.rep, "scenario", scenario, "M=", M, ":", e$message, "\n")
          m_results$ps_weighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
        })
        
        # ============================================================
        # METHOD 5: WDSM with Multinomial Bootstrap
        # ============================================================
        tryCatch({
          # WDSM needs data frame with specific names
          wdsm_sample <- data.frame(
            Y = Y,
            A = A,
            X1 = X[,1], X2 = X[,2], X3 = X[,3],
            X4 = X[,4], X5 = X[,5], X6 = X[,6],
            survey_weight = w_raw
          )
          
          # WDSM uses Normal Wald CI (confirmed)
          ci_results <- method2_multinomial_bootstrap_ci(
            data = wdsm_sample,
            estimand = "PATE",
            M = M,
            B = B,
            alpha = alpha,
            use_interaction_ps = use_interaction_ps,
            use_interaction_pg = use_interaction_pg
          )
          
          m_results$wdsm_multinomial <- list(
            estimate = ci_results$estimate,
            se = ci_results$se,
            ci_lower = ci_results$ci_lower,
            ci_upper = ci_results$ci_upper
          )
        }, error = function(e) {
          cat("WDSM Error in rep", i.rep, "scenario", scenario, "M=", M, ":", e$message, "\n")
          m_results$wdsm_multinomial <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
        })
        
        # Store results
        replicate_results[[paste0(scenario, "_M", M)]] <- m_results
        
      } # End M loop
    } # End scenario loop
    
    return(replicate_results)
    
  }, error = function(e) {
    return(list(error = paste("Replicate", i.rep, "failed:", e$message)))
  })
}

# ============================================================================
# Load Population Data
# ============================================================================
cat("\n============================================================\n")
cat("Loading population data...\n")
cat("============================================================\n")

load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_GoodOverlap_AllinOne_0118_2025

# Use first dataset - KEEP ORIGINAL VARIABLE NAMES
population <- data_sets[[1]]

# Calculate true PATE using original names
true_pate <- mean(population$y1 - population$y0)
cat("\nTrue Population PATE:", round(true_pate, 4), "\n")

# ============================================================================
# Simulation Parameters
# ============================================================================
n_reps <- 1000    # Number of simulation replicates
n_sample <- 5000  # Sample size for retrospective sampling
M_values <- c(1, 3, 5)  # Number of matches per unit
B <- 200         # Bootstrap iterations
alpha <- 0.05    # Significance level

# Get scenario from environment or default to all 4
scenarios <- Sys.getenv("SCENARIO")
if (scenarios == "") {
  scenarios <- c("CorCor")
} else {
  scenarios <- c(scenarios)
}

# ============================================================================
# Main Simulation
# ============================================================================
start_time <- Sys.time()

cat("\n============================================================\n")
cat("Running PATE Retrospective Sampling Comparison\n")
cat("Model Specification Scenarios:", paste(scenarios, collapse=", "), "\n")
cat("============================================================\n")
cat("\nSample size:", n_sample, "\n")
cat("Number of replicates:", n_reps, "\n")
cat("M values:", paste(M_values, collapse=", "), "\n")
cat("Bootstrap iterations:", B, "\n")
cat("Scenarios:", paste(scenarios, collapse=", "), "\n")

# Setup parallel processing
n_cores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "48"))  # Auto-detect from SLURM or default to 48
batch_size <- 100

cat("\nSetting up", n_cores, "cores for parallel processing...\n")
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

# Run simulations in parallel
all_results <- foreach(i.rep = 1:n_reps,
                       .combine = 'c',
                       .multicombine = TRUE,
                       .maxcombine = batch_size,
                       .inorder = FALSE,
                       .errorhandling = 'pass',
                       .packages = c("survey", "sampling", "MatchIt", "MASS", 
                                    "boot", "nnet", "marginaleffects", "dplyr", 
                                    "tidyr", "purrr", "matrixStats", "Hmisc"),
                       .export = c("run_single_replicate", "population", "true_pate",
                                  "n_sample", "M_values", "B", "alpha", "scenarios",
                                  "retrospective_sample", "wdsm_point_estimate",
                                  "method2_multinomial_bootstrap_ci",
                                  "expit", "weighted_distance", "find_weighted_neighbors",
                                  "calculate_weighted_reuse_counts", "compute_wdsm_method2_ci")) %dopar% {
  
  if (i.rep %% 50 == 0) {
    cat("Starting replicate", i.rep, "of", n_reps, "\n")
  }
  
  set.seed(20250127 + i.rep)
  gc()
  
  result <- run_single_replicate(i.rep, population, true_pate, n_sample, M_values, B, alpha, scenarios)
  
  gc()
  list(result)
}

# Cleanup
stopCluster(cl)
end_time <- Sys.time()
total_time <- difftime(end_time, start_time, units = "mins")

cat("\n============================================================\n")
cat("Simulation completed in", round(total_time, 2), "minutes\n")
cat("============================================================\n")

# ============================================================================
# Save Raw Results IMMEDIATELY
# ============================================================================
cat("\nSaving raw results...\n")
save(all_results, file = paste0("raw_results_", paste(scenarios, collapse="_"), "_M", paste(M_values, collapse=""), ".RData"))

# ============================================================================
# Process Results (with error handling)
# ============================================================================
cat("\nProcessing results...\n")

tryCatch({
  # Filter valid results
  valid_results <- all_results[sapply(all_results, function(x) !is.null(x) && !inherits(x, "error"))]
  successful_runs <- length(valid_results)
  
  cat("\nSuccessful runs:", successful_runs, "out of", n_reps, "\n")
  
  if (successful_runs > 0) {
    # Create summary tables for each scenario and M combination
    summary_tables <- list()
    
    for (scenario in scenarios) {
      for (M in M_values) {
        key <- paste0(scenario, "_M", M)
        
        # Extract results using lapply and unlist for robustness
        estimates <- list(
          dsm_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$dsm_unweighted$estimate)),
          pg_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$pg_unweighted$estimate)),
          ps_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$ps_unweighted$estimate)),
          ps_weighted = unlist(lapply(valid_results, function(x) x[[key]]$ps_weighted$estimate)),
          wdsm_multinomial = unlist(lapply(valid_results, function(x) x[[key]]$wdsm_multinomial$estimate))
        )
        
        ses <- list(
          dsm_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$dsm_unweighted$se)),
          pg_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$pg_unweighted$se)),
          ps_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$ps_unweighted$se)),
          ps_weighted = unlist(lapply(valid_results, function(x) x[[key]]$ps_weighted$se)),
          wdsm_multinomial = unlist(lapply(valid_results, function(x) x[[key]]$wdsm_multinomial$se))
        )
        
        ci_lowers <- list(
          dsm_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$dsm_unweighted$ci_lower)),
          pg_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$pg_unweighted$ci_lower)),
          ps_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$ps_unweighted$ci_lower)),
          ps_weighted = unlist(lapply(valid_results, function(x) x[[key]]$ps_weighted$ci_lower)),
          wdsm_multinomial = unlist(lapply(valid_results, function(x) x[[key]]$wdsm_multinomial$ci_lower))
        )
        
        ci_uppers <- list(
          dsm_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$dsm_unweighted$ci_upper)),
          pg_unweighted = unlist(lapply(valid_results, function(x) x[[key]]$pg_unweighted$ci_upper)),
          ps_weighted = unlist(lapply(valid_results, function(x) x[[key]]$ps_weighted$ci_upper)),
          wdsm_multinomial = unlist(lapply(valid_results, function(x) x[[key]]$wdsm_multinomial$ci_upper))
        )
        
        # Create summary
        summary <- data.frame(
          Method = c("DSM Unweighted", "PG Unweighted", "PS Unweighted", 
                    "PS Weighted (Full)", "WDSM Multinomial"),
          Mean_Estimate = sapply(estimates, function(x) mean(x, na.rm=TRUE)),
          Empirical_SD = sapply(estimates, function(x) sd(x, na.rm=TRUE)),
          Mean_SE = sapply(ses, function(x) mean(x, na.rm=TRUE)),
          Relative_Bias = sapply(estimates, function(x) (mean(x, na.rm=TRUE) - true_pate) / abs(true_pate)),
          Coverage = mapply(function(lower, upper) {
            mean(true_pate >= lower & true_pate <= upper, na.rm=TRUE)
          }, ci_lowers, ci_uppers),
          RMSE = sapply(estimates, function(x) sqrt(mean((x - true_pate)^2, na.rm=TRUE))),
          stringsAsFactors = FALSE
        )
        
        # Add SE Ratio (Mean_SE / Empirical_SD)
        summary$SE_Ratio <- summary$Mean_SE / summary$Empirical_SD
        
        # PS Unweighted as reference
        ps_emp_sd <- summary$Empirical_SD[summary$Method == "PS Unweighted"]
        summary$Relative_Efficiency <- summary$Empirical_SD / ps_emp_sd
        
        summary_tables[[key]] <- summary
        
        cat("\n", scenario, "- M =", M, ":\n")
        print(round(summary[,c("Method", "Relative_Bias", "SE_Ratio", "Coverage")], 3))
      }
    }
    
    # Save processed results
    save(summary_tables, file = paste0("processed_results_", paste(scenarios, collapse="_"), "_M", paste(M_values, collapse=""), ".RData"))
  }
  
}, error = function(e) {
  cat("\nError in processing results:", e$message, "\n")
  cat("Raw results have been saved for later processing.\n")
})

cat("\n============================================================\n")
cat("SIMULATION COMPLETE\n")
cat("============================================================\n")
