##############################################################################
# FULLY FIXED VERSION v3 - 20 Replicates Test Run
# Poor Overlap PATE under Retrospective Sampling
# Scenario: MisMis
# Following the correct structure from Good Overlap version
##############################################################################

# ============================================================================
# Setup and Libraries
# ============================================================================
suppressPackageStartupMessages({
  library(MASS)
  library(survey)
  library(sampling)
  library(MatchIt)
  library(boot)
  library(mvtnorm)
  library(nnet)
  library(doParallel)
  library(foreach)
  library(marginaleffects)
  library(R.utils)
})

# Source functions GLOBALLY (like in good overlap version)
# Source ALL necessary dsmatch functions
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

# Source WDSM functions (includes retrospective_sample)
source("wdsm_method2_multinomial_bootstrap.R")
source("wdsm_ci_functions.R")

# ============================================================================
# Simulation Parameters
# ============================================================================
n_reps <- 20  # TEST RUN with 20 replicates
n_sample <- 5000  # Sample size for retrospective sampling
M_values <- c(5)  # Only M=5 for test
B <- 200  # Bootstrap iterations
alpha <- 0.05
scenarios <- c("MisMis")

# ============================================================================
# Function to run a single replicate
# ============================================================================
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M_values, B, alpha, scenarios) {
  
  tryCatch({
    # Source functions INSIDE the worker (for parallel execution)
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
    
    # Retrospective sampling (using function from wdsm_ci_functions.R)
    sample <- retrospective_sample(population, n_sample = n_sample)
    
    # Extract variables
    Y <- sample$Y
    X <- as.matrix(sample[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    A <- sample$A
    
    # Extract survey weights
    w_raw <- sample$survey_weight
    # Normalized weights for PS Full
    w_normalized <- w_raw * length(w_raw) / sum(w_raw)
    
    # Initialize results
    replicate_results <- list()
    
    # Loop over scenarios
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
      
      # Loop over M values
      for (M in M_values) {
        
        m_results <- list()
        
        # ============================================================
        # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING
        # ============================================================
        tryCatch({
          dsm_result <- dsmatchATE(
            Y = Y,
            X = X_ps,
            A = A,
            method = "dsm",
            model.ps = "logit",
            model.pg = "linpred",
            lp.pg = X_pg,
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
          cat("DSM error:", e$message, "\n")
          m_results$dsm_unweighted <- list(
            estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 2: UNWEIGHTED PROGNOSTIC SCORE MATCHING
        # ============================================================
        tryCatch({
          pg_result <- dsmatchATE(
            Y = Y,
            X = X_pg,
            A = A,
            method = "pg",
            model.pg = "glm",
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
          cat("PG error:", e$message, "\n")
          m_results$pg_unweighted <- list(
            estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 3: UNWEIGHTED PROPENSITY SCORE MATCHING
        # ============================================================
        tryCatch({
          ps_result <- dsmatchATE(
            Y = Y,
            X = X_ps,
            A = A,
            method = "ps",
            model.ps = "logit",
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
          cat("PS error:", e$message, "\n")
          m_results$ps_unweighted <- list(
            estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 4: SURVEY-WEIGHTED PS FULL MATCHING
        # ============================================================
        tryCatch({
          formula_ps_matchit <- if (use_interaction_ps) {
            as.formula("A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2")
          } else {
            as.formula("A ~ x1 + x2 + x3 + x4 + x5 + x6")
          }
          
          data_matchit <- data.frame(
            Y = Y,
            A = A,
            x1 = X[,1], x2 = X[,2], x3 = X[,3],
            x4 = X[,4], x5 = X[,5], x6 = X[,6],
            sw = w_normalized
          )
          
          match_full <- matchit(
            formula_ps_matchit,
            data = data_matchit,
            method = "full",
            distance = "glm",
            link = "logit",
            s.weights = data_matchit$sw
          )
          
          matched_data <- match.data(match_full)
          
          # Always use correct outcome model for bias correction
          fit <- lm(Y ~ A * (x1 + x2 + x3 + x4 + x5 + x6 + x1:x2),
                   data = matched_data,
                   weights = sw * weights)
          
          ate_result <- avg_comparisons(
            fit,
            variables = "A",
            vcov = ~subclass,
            wts = "sw"
          )
          
          m_results$ps_weighted <- list(
            estimate = ate_result$estimate,
            se = ate_result$std.error,
            ci_lower = ate_result$conf.low,
            ci_upper = ate_result$conf.high
          )
        }, error = function(e) {
          cat("PS Full error:", e$message, "\n")
          m_results$ps_weighted <- list(
            estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 5: WDSM with Multinomial Bootstrap
        # ============================================================
        tryCatch({
          ci_results <- compute_wdsm_method2_ci_FIXED(
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
          cat("WDSM error:", e$message, "\n")
          m_results$wdsm_multinomial <- list(
            estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
          )
        })
        
        # Store results for this scenario and M
        key <- paste0(scenario, "_M", M)
        replicate_results[[key]] <- m_results
      }
    }
    
    return(replicate_results)
    
  }, error = function(e) {
    cat("Error in replicate", i.rep, ":", e$message, "\n")
    return(list(error = e$message))
  })
}

# ============================================================================
# Load Data (Following Good Overlap Structure)
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

# Calculate true population PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("\nTrue Population PATE:", round(true_pate, 4), "\n")
cat("Population size:", nrow(population), "\n")
cat("Sample size:", n_sample, "\n")

# ============================================================================
# Run Simulation
# ============================================================================
start_time <- Sys.time()

# Set up parallel cluster
n_cores <- 12
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

cat("\n============================================================\n")
cat("Starting simulation with", n_reps, "replicates using", n_cores, "cores\n")
cat("Scenario:", scenarios[1], "\n")
cat("M value:", M_values[1], "\n")
cat("============================================================\n")

# Run simulation in parallel
all_results <- foreach(i.rep = 1:n_reps,
                      .errorhandling = 'pass',
                      .packages = c("survey", "sampling", "MatchIt", "MASS", 
                                   "boot", "nnet", "marginaleffects", "R.utils"),
                      .export = c("run_single_replicate", "population", "true_pate",
                                 "n_sample", "M_values", "B", "alpha", "scenarios",
                                 "retrospective_sample", "calculate_weighted_reuse_counts_FIXED", "fit_mu_on_scores", "predict_mu_on_scores", "standardize_with_weights", "weighted_distance", "find_weighted_neighbors", "wdsm_point_estimate_FIXED",
                                 "method2_multinomial_bootstrap_ci_FIXED", "fit_mu_on_scores_bootstrap",
                                 "compute_wdsm_method2_ci_FIXED")) %dopar% {
  
  cat("Starting replicate", i.rep, "of", n_reps, "\n")
  set.seed(20250127 + i.rep)
  
  result <- run_single_replicate(i.rep, population, true_pate, n_sample, 
                                M_values, B, alpha, scenarios)
  
  # Force garbage collection
  gc()
  
  return(result)
}

# Clean up parallel cluster
stopCluster(cl)

end_time <- Sys.time()
total_time <- difftime(end_time, start_time, units = "mins")

cat("\n============================================================\n")
cat("Simulation completed in", round(total_time, 2), "minutes\n")
cat("============================================================\n")

# ============================================================================
# Process Results
# ============================================================================
successful_runs <- sum(sapply(all_results, function(x) !is.null(x) && !inherits(x, "error") && !"error" %in% names(x)))
cat("\nSuccessful runs:", successful_runs, "out of", n_reps, "\n")

# Save raw results
save(all_results, file = paste0("raw_results_20reps_", scenarios[1], "_FIXED_V3.RData"))

# Process and display summary
if (successful_runs > 0) {
  valid_results <- all_results[sapply(all_results, function(x) !is.null(x) && !inherits(x, "error") && !"error" %in% names(x))]
  
  # Extract results for the scenario and M
  key <- paste0(scenarios[1], "_M", M_values[1])
  scenario_results <- lapply(valid_results, function(x) x[[key]])
  
  # Calculate metrics for each method
  methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", "wdsm_multinomial")
  
  cat("\n============================================================\n")
  cat("RESULTS SUMMARY (", successful_runs, " replicates)\n")
  cat("True PATE:", round(true_pate, 4), "\n")
  cat("============================================================\n")
  cat(sprintf("%-20s %8s %8s %8s %8s\n", 
              "Method", "Bias", "SE", "Coverage", "RMSE"))
  cat("------------------------------------------------------------\n")
  
  for (method in methods) {
    estimates <- sapply(scenario_results, function(x) {
      if (!is.null(x[[method]]$estimate)) x[[method]]$estimate else NA
    })
    ses <- sapply(scenario_results, function(x) {
      if (!is.null(x[[method]]$se)) x[[method]]$se else NA
    })
    ci_lowers <- sapply(scenario_results, function(x) {
      if (!is.null(x[[method]]$ci_lower)) x[[method]]$ci_lower else NA
    })
    ci_uppers <- sapply(scenario_results, function(x) {
      if (!is.null(x[[method]]$ci_upper)) x[[method]]$ci_upper else NA
    })
    
    # Remove NAs
    valid_idx <- !is.na(estimates)
    if (sum(valid_idx) > 0) {
      estimates <- estimates[valid_idx]
      ses <- ses[valid_idx]
      ci_lowers <- ci_lowers[valid_idx]
      ci_uppers <- ci_uppers[valid_idx]
      
      bias <- mean(estimates) - true_pate
      rel_bias <- bias / abs(true_pate)
      emp_se <- sd(estimates)
      mean_se <- mean(ses)
      se_ratio <- mean_se / emp_se
      coverage <- mean(ci_lowers <= true_pate & ci_uppers >= true_pate)
      rmse <- sqrt(mean((estimates - true_pate)^2))
      
      cat(sprintf("%-20s %8.3f %8.3f %8.2f %8.3f\n",
                 method, rel_bias * 100, se_ratio, coverage * 100, rmse))
    } else {
      cat(sprintf("%-20s     FAILED\n", method))
    }
  }
}

cat("\n============================================================\n")
cat("TEST RUN COMPLETE!\n")
cat("Results saved to: raw_results_20reps_", scenarios[1], "_FIXED_V3.RData\n")
cat("============================================================\n")
