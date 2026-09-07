# PROPERLY_SOURCED VERSION - Fixed missing wdsm_method2_multinomial_bootstrap.R source
# This version correctly sources BOTH:
#   1. wdsm_method2_multinomial_bootstrap.R (contains compute_wdsm_method2_ci)
#   2. wdsm_ci_functions.R (contains wdsm_point_estimate)
##############################################################################
# Comprehensive Comparison for Poor Overlap Data
# PATE under Retrospective Sampling - McCleary HPC Version
# Scenario: MisCor
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
library(R.utils)  # For withTimeout (but not using it)

# Source required functions
cat("Sourcing custom functions...\n")

# Source ALL necessary dsmatch functions at top level
cat("Sourcing dsmatch functions...\n")
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

# Source WDSM functions
source("wdsm_method2_multinomial_bootstrap.R")
source("wdsm_ci_functions.R")
source("wdsm_method2_multinomial_bootstrap.R")

# ============================================================================
# Function Definitions
# ============================================================================
# Function to perform retrospective sampling
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Stratified sampling on A
  n1 <- floor(n_sample / 2)
  n0 <- n_sample - n1
  
  # Sample indices
  idx1 <- sample(which(population$A == 1), n1, replace = FALSE)
  idx0 <- sample(which(population$A == 0), n0, replace = FALSE)
  
  # Combine samples
  idx <- c(idx1, idx0)
  sample_data <- population[idx, ]
  
  # Calculate sampling weights
  N1 <- sum(population$A == 1)
  N0 <- N - N1
  sample_data$survey_weight <- ifelse(sample_data$A == 1, N1/n1, N0/n0)
  
  return(sample_data)
}

# Function to run a single replicate
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M_values, B, alpha, scenarios) {
  
  tryCatch({
    # CRITICAL: Source dsmatch functions INSIDE the worker
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
    
    # Also source WDSM functions inside worker
    source("wdsm_method2_multinomial_bootstrap.R")
    source("wdsm_ci_functions.R")
    
    # Retrospective sampling (done once per replicate)
    sample <- retrospective_sample(population, n_sample = n_sample)
    
    # Extract variables
    Y <- sample$Y
    X <- as.matrix(sample[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    A <- sample$A
    
    # Extract survey weights
    w_raw <- sample$survey_weight
    # Normalized weights for PS Full (required for proper variance estimation)
    w_normalized <- w_raw * length(w_raw) / sum(w_raw)
    
    # Initialize results for all M values and scenarios
    replicate_results <- list()
    
    # Loop over different model specification scenarios
    for (scenario in scenarios) {
      
      # Determine which models to use based on scenario
      use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
      use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
      
      # Create X matrices for PS and PG models based on scenario
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
    
      # Loop over different M values
      for (M in M_values) {
        
        # Initialize results for this M value and scenario
        m_results <- list()
        
        # ============================================================
        # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch-master)
        # ============================================================
        tryCatch({
          # Run DSM with bootstrap (NO M PARAMETER - matching Good Overlap)
          dsm_result <- dsmatchATE(
            Y = Y,
            X = X_ps,  # PS model uses X_ps (with/without interaction)
            A = A,
            method = "dsm",
            model.ps = "logit",  # Fit logit model on X
            model.pg = "linpred",  # Use linear predictors for PG
            lp.pg = X_pg,  # PG model uses X_pg (with/without interaction)
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
          cat("DSM Unweighted Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$dsm_unweighted <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 2: UNWEIGHTED PROGNOSTIC SCORE MATCHING (dsmatch-master)
        # ============================================================
        tryCatch({
          # Run PG matching with bootstrap (NO M PARAMETER - matching Good Overlap)
          pg_result <- dsmatchATE(
            Y = Y,
            X = X_pg,
            A = A,
            method = "pg",
            model.pg = "glm",  # Linear model for continuous outcome
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
          cat("PG Unweighted Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$pg_unweighted <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 3: UNWEIGHTED PROPENSITY SCORE MATCHING (dsmatch-master)
        # ============================================================
        tryCatch({
          # Run PS matching with bootstrap (NO M PARAMETER - matching Good Overlap)
          ps_result <- dsmatchATE(
            Y = Y,
            X = X_ps,
            A = A,
            method = "ps",
            model.ps = "logit",  # Always logit for PS
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
          cat("PS Unweighted Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$ps_unweighted <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 4: SURVEY-WEIGHTED PROPENSITY SCORE MATCHING (MatchIt)
        # ============================================================
        tryCatch({
          # Create data frame with normalized survey weights
          match_data_sw <- data.frame(
            Y = Y,
            A = A,
            X1 = X[,1],
            X2 = X[,2],
            X3 = X[,3],
            X4 = X[,4],
            X5 = X[,5],
            X6 = X[,6],
            sw = w_normalized
          )
          
          # PS formula based on scenario
          ps_formula <- if (use_interaction_ps) {
            A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
          } else {
            A ~ X1 + X2 + X3 + X4 + X5 + X6
          }
          
          # Run survey-weighted propensity score matching using full matching for ATE
          m_ps_sw <- matchit(
            ps_formula,
            data = match_data_sw,
            method = "full",
            distance = "glm",
            link = "logit",
            s.weights = ~ sw,
            estimand = "ATE"
          )
          
          # Extract matched data with combined weights
          md_sw <- match.data(m_ps_sw)
          
          # Outcome model formula based on PGS scenario
          outcome_formula <- if (use_interaction_pg) {
            Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2)
          } else {
            Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6)
          }
          
          # Fit outcome model with product weights
          fit_sw <- lm(outcome_formula,
                      data = md_sw,
                      weights = weights)
          
          # Estimate marginal ATE using g-computation
          ate_result <- avg_comparisons(
            fit_sw,
            variables = "A",
            vcov = ~subclass,
            wts = md_sw$sw
          )
          
          # Extract results
          m_results$ps_weighted <- list(
            estimate = ate_result$estimate,
            se = ate_result$std.error,
            ci_lower = ate_result$conf.low,
            ci_upper = ate_result$conf.high
          )
          
        }, error = function(e) {
          cat("PS Survey-Weighted Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$ps_weighted <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 5: WDSM with Multinomial Bootstrap
        # ============================================================
        tryCatch({
          # WDSM uses the scenario-specific covariate specifications
          ci_results <- compute_wdsm_method2_ci(
            Y = Y, 
            A = A, 
            X = X,
            weights = w_raw,
            M = M,
            n_bootstrap = B,
            alpha = alpha,
            use_bias_correction = TRUE,
            return_samples = FALSE,
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
          cat("WDSM Multinomial Bootstrap Error in replicate", i.rep, ", scenario", scenario, ":", e$message, "\n")
          m_results$wdsm_multinomial <- list(
            estimate = NA,
            se = NA,
            ci_lower = NA,
            ci_upper = NA
          )
        })
        
        # Store results for this M value and scenario
        replicate_results[[paste0(scenario, "_M", M)]] <- m_results
        
      } # End of M loop
    } # End of scenario loop
    
    return(replicate_results)
    
  }, error = function(e) {
    return(list(error = paste("Replicate", i.rep, "failed:", e$message)))
  })
}

# ============================================================================
# Load Data
# ============================================================================
cat("\n============================================================\n")
cat("Loading population data...\n")
cat("============================================================\n")

load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_PoorOverlap_AllinOne_0118_2025

# Extract first dataset and rename columns to match our convention
population <- data_sets[[1]]
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "y"] <- "Y"
names(population)[names(population) == "y0"] <- "Y0"
names(population)[names(population) == "y1"] <- "Y1"
for (i in 1:6) {
  names(population)[names(population) == paste0("x", i)] <- paste0("X", i)
}

# Parameters
n_reps <- 100     # Number of simulation replicates
n_sample <- 5000  # Sample size for retrospective sampling
M_values <- c(5)  # Number of matches per unit (NOTE: dsmatchATE does 1:1 by default)
B <- 200          # Bootstrap iterations
alpha <- 0.05     # Significance level
scenarios <- c("MisCor")  # Model specification scenario - Both Correct

# Calculate true population PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("\nTrue Population PATE:", round(true_pate, 4), "\n")

# ============================================================================
# Main Simulation Loop with FORK Cluster
# ============================================================================
start_time <- Sys.time()

cat("\n============================================================\n")
cat("Running PATE Retrospective Sampling Comparison\n")
cat("Poor Overlap Data - CorCor Scenario\n")
cat("============================================================\n")
cat("\nSample size:", n_sample, "\n")
cat("Number of replicates:", n_reps, "\n")
cat("Bootstrap iterations:", B, "\n")
cat("Significance level:", alpha, "\n")
cat("Model scenario: CorCor (Both PS and PGS correct)\n")
cat("\nNOTE: dsmatchATE does 1:1 matching by default (M parameter removed)\n")

# Set up parallel backend with FORK cluster for better stability
n_cores <- 20  # Using 20 cores for 100 reps
cat("\n============================================================\n")
cat("Setting up parallel backend with", n_cores, "cores (FORK cluster)...\n")
cat("============================================================\n")

cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

# Run simulation with larger batch size
batch_size <- 20  # Process in batches

cat("\nRunning simulation in batches of", batch_size, "replicates each...\n")
cat("============================================================\n")

# Run replicates in parallel WITHOUT individual timeout (job has 23 hour limit)
all_results <- foreach(i.rep = 1:n_reps,
                      .combine = 'c',
                      .multicombine = TRUE,
                      .maxcombine = batch_size,
                      .inorder = FALSE,
                      .errorhandling = 'pass',
                      .packages = c("survey", "sampling", "MatchIt", "MASS", 
                                   "boot", "nnet", "marginaleffects"),
                      .export = c("run_single_replicate", "population", "true_pate",
                                 "n_sample", "M_values", "B", "alpha", "scenarios",
                                 "retrospective_sample", "wdsm_point_estimate",
                                 "method2_multinomial_bootstrap_ci",
                                 "expit", "weighted_distance", "find_weighted_neighbors",
                                 "calculate_weighted_reuse_counts", "compute_wdsm_method2_ci")) %dopar% {
  
  # Progress tracking
  if (i.rep %% 10 == 0) {
    cat("Starting replicate", i.rep, "of", n_reps, "\n")
  }
  
  # Set random seed for this replicate
  set.seed(20250127 + i.rep)
  
  # Run with memory management
  gc()  # Garbage collection before starting
  
  # Run single replicate WITHOUT timeout (let it run fully)
  result <- run_single_replicate(i.rep, population, true_pate, n_sample, M_values, B, alpha, scenarios)
  
  gc()  # Garbage collection after completion
  
  list(result)  # Wrap in list for combine
}

# Clean up parallel cluster
stopCluster(cl)

# ============================================================================
# Process Results
# ============================================================================
cat("\n============================================================\n")
cat("Processing results...\n")
cat("============================================================\n")

# Filter out errors and organize results
valid_results <- list()
error_count <- 0
for (i in 1:length(all_results)) {
  if (!is.null(all_results[[i]]) && !inherits(all_results[[i]], "error")) {
    if (!is.null(all_results[[i]]$error)) {
      error_count <- error_count + 1
      cat("Replicate", i, "had error:", all_results[[i]]$error, "\n")
    } else {
      valid_results[[paste0("rep_", i)]] <- all_results[[i]]
    }
  } else if (inherits(all_results[[i]], "error")) {
    error_count <- error_count + 1
    cat("Replicate", i, "error:", all_results[[i]]$message, "\n")
  }
}

cat("\nSuccessfully completed", length(valid_results), "out of", n_reps, "replicates\n")
if (error_count > 0) {
  cat("Failed replicates:", error_count, "\n")
}

# Organize results by scenario and M
results_by_scenario_m <- list()
for (scenario in scenarios) {
  for (M in M_values) {
    key <- paste0(scenario, "_M", M)
    results_by_scenario_m[[key]] <- list()
    
    for (rep_name in names(valid_results)) {
      if (key %in% names(valid_results[[rep_name]])) {
        results_by_scenario_m[[key]][[rep_name]] <- valid_results[[rep_name]][[key]]
      }
    }
  }
}

# Create summary table
summary_data <- data.frame()

for (scenario in scenarios) {
  for (M in M_values) {
    key <- paste0(scenario, "_M", M)
    
    if (key %in% names(results_by_scenario_m)) {
      scenario_m_results <- results_by_scenario_m[[key]]
      
      # Extract results for each method
      methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
                  "ps_weighted", "wdsm_multinomial")
      
      for (method in methods) {
        estimates <- c()
        ses <- c()
        ci_lowers <- c()
        ci_uppers <- c()
        
        for (rep_name in names(scenario_m_results)) {
          if (method %in% names(scenario_m_results[[rep_name]])) {
            result <- scenario_m_results[[rep_name]][[method]]
            if (!is.na(result$estimate)) {
              estimates <- c(estimates, result$estimate)
              ses <- c(ses, result$se)
              ci_lowers <- c(ci_lowers, result$ci_lower)
              ci_uppers <- c(ci_uppers, result$ci_upper)
            }
          }
        }
        
        if (length(estimates) > 0) {
          # Calculate metrics
          mean_estimate <- mean(estimates)
          bias <- mean(estimates) - true_pate
          rel_bias <- (mean(estimates) - true_pate) / abs(true_pate)
          emp_se <- sd(estimates)
          mean_se <- mean(ses)
          se_ratio <- mean_se / emp_se
          coverage <- mean(ci_lowers <= true_pate & ci_uppers >= true_pate)
          rmse <- sqrt(mean((estimates - true_pate)^2))
          
          summary_data <- rbind(summary_data, data.frame(
            Scenario = scenario,
            M = "1:1",  # Note: dsmatchATE does 1:1 matching
            Method = method,
            N_Valid = length(estimates),
            Mean_Estimate = mean_estimate,
            Bias = bias,
            Rel_Bias = rel_bias,
            Empirical_SE = emp_se,
            Mean_SE = mean_se,
            SE_Ratio = se_ratio,
            Coverage = coverage,
            RMSE = rmse,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }
}

# Round numeric columns for display
numeric_cols <- c("Mean_Estimate", "Bias", "Rel_Bias", "Empirical_SE", 
                 "Mean_SE", "SE_Ratio", "Coverage", "RMSE")
summary_data[numeric_cols] <- round(summary_data[numeric_cols], 4)

# Display results
cat("\n============================================================\n")
cat("Summary Results\n")
cat("============================================================\n")
print(summary_data)

cat("\nTrue PATE:", round(true_pate, 4), "\n")

# Save results
write.csv(summary_data, 
         "pate_retrospective_pooroverlap_comparison_table_M5_100reps_MisCor_FINAL.csv",
         row.names = FALSE)

save(all_results, valid_results, results_by_scenario_m, summary_data, true_pate,
     file = "pate_retrospective_pooroverlap_comparison_results_M5_100reps_MisCor_FINAL.RData")

# Print completion time
end_time <- Sys.time()
total_time <- difftime(end_time, start_time, units = "mins")

cat("\n============================================================\n")
cat("Analysis complete!\n")
cat("Total time:", round(total_time, 2), "minutes\n")
cat("Results saved to CSV and RData files\n")
cat("NOTE: M parameter removed - dsmatchATE does 1:1 matching by default\n")
cat("NOTE: No individual timeouts - job has 23 hour limit\n")
cat("============================================================\n")
