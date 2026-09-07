#!/bin/bash

echo "==============================================================="
echo "Creating 20-rep test scripts with FULLY FIXED WDSM"
echo "==============================================================="
echo ""

# Create updated comparison script for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    SCRIPT="$DIR/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R"
    
    echo "Creating script for $scenario..."
    
    cat > "$SCRIPT" << 'EOF'
##############################################################################
# FULLY FIXED VERSION - 20 Replicates Test Run
# Poor Overlap PATE under Retrospective Sampling
EOF
    echo "# Scenario: $scenario" >> "$SCRIPT"
    
    cat >> "$SCRIPT" << 'EOF'
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

# ============================================================================
# Simulation Parameters
# ============================================================================
n_reps <- 20  # TEST RUN with 20 replicates
n_sample <- 1000
M_values <- c(5)  # Only M=5 for test
B <- 200  # Bootstrap iterations
alpha <- 0.05
EOF
    
    echo "scenarios <- c(\"$scenario\")" >> "$SCRIPT"
    
    cat >> "$SCRIPT" << 'EOF'

# ============================================================================
# Function to perform retrospective sampling (CORRECTED from SW_PSW-main)
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Coefficients for sample selection model (from SW_PSW-main)
  c0 <- log(n_sample/N / (1 - n_sample/N))
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)
  
  # Calculate sampling probabilities based on covariates and treatment
  formula_S <- c0 + delta_z_in_s * population$A + 
               c1 * population$X1 + c2 * population$X2 +
               c3 * population$X3 + c4 * population$X4 + 
               c5 * population$X5 + c6 * population$X6
  
  # Expit transformation for probabilities
  prob_S <- exp(formula_S) / (1 + exp(formula_S))
  population$Prob <- prob_S
  
  # Sample units based on probabilities
  population$S <- rbinom(N, 1, prob_S)
  sample_data <- population[population$S == 1, ]
  
  # Calculate survey weights as inverse of sampling probability
  sample_data$survey_weight <- 1 / sample_data$Prob
  
  return(sample_data)
}

# Function to run a single replicate
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M_values, B, alpha, scenarios) {
  
  tryCatch({
    # CRITICAL: Source functions INSIDE the worker
    dsmatch_files <- c(
      "dsmatch-master/R/dsmatchATE.R",
      "dsmatch-master/R/bisect.R",
      "dsmatch-master/R/is.lp.R",
      "dsmatch-master/R/is.ps.R", 
      "dsmatch-master/R/is.pg.R",
      "dsmatch-master/R/estforboot_dsATE.R",
      "dsmatch-master/R/estforboot_psATE.R",
      "dsmatch-master/R/estforboot_pgATE.R",
      "dsmatch-master/R/estforboot_covATE.R"
    )
    
    for (file in dsmatch_files) {
      source(file)
    }
    
    # Source FULLY FIXED WDSM functions
    source("wdsm_method2_multinomial_bootstrap.R")
    source("wdsm_ci_functions.R")
    
    # Retrospective sampling
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
            estimate = dsm_result$treatment.effect,
            se = dsm_result$standard.error,
            ci_lower = dsm_result$CI[1],
            ci_upper = dsm_result$CI[2]
          )
        }, error = function(e) {
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
            estimate = pg_result$treatment.effect,
            se = pg_result$standard.error,
            ci_lower = pg_result$CI[1],
            ci_upper = pg_result$CI[2]
          )
        }, error = function(e) {
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
            estimate = ps_result$treatment.effect,
            se = ps_result$standard.error,
            ci_lower = ps_result$CI[1],
            ci_upper = ps_result$CI[2]
          )
        }, error = function(e) {
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
          m_results$ps_weighted <- list(
            estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
          )
        })
        
        # ============================================================
        # METHOD 5: FULLY FIXED WDSM with Multinomial Bootstrap
        # ============================================================
        tryCatch({
          # Use the FULLY FIXED function
          if (exists("compute_wdsm_method2_ci_FULLY_FIXED")) {
            ci_results <- compute_wdsm_method2_ci_FULLY_FIXED(
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
          } else {
            # Fall back to regular version if FULLY_FIXED not available
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
          }
          
          m_results$wdsm_multinomial <- list(
            estimate = ci_results$estimate,
            se = ci_results$se,
            ci_lower = ci_results$ci_lower,
            ci_upper = ci_results$ci_upper
          )
        }, error = function(e) {
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
# Load Data
# ============================================================================
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
population <- SuperPopGen_PoorOverlap_AllinOne_0118_2025[[1]]

# Rename outcome columns for consistency
names(population)[names(population) == "y0"] <- "Y0"
names(population)[names(population) == "y1"] <- "Y1"
names(population)[names(population) == "y"] <- "Y"
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "x1"] <- "X1"
names(population)[names(population) == "x2"] <- "X2"
names(population)[names(population) == "x3"] <- "X3"
names(population)[names(population) == "x4"] <- "X4"
names(population)[names(population) == "x5"] <- "X5"
names(population)[names(population) == "x6"] <- "X6"

# Calculate true population PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("\nTrue Population PATE:", round(true_pate, 4), "\n")

# ============================================================================
# Run Simulation
# ============================================================================
start_time <- Sys.time()

# Set up parallel cluster
n_cores <- 10  # Use 10 cores for test run
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

cat("\n============================================================\n")
cat("Starting simulation with", n_reps, "replicates using", n_cores, "cores\n")
cat("Scenario:", scenarios[1], "\n")
cat("M value:", M_values[1], "\n")
cat("============================================================\n")

# Run simulation in parallel
all_results <- foreach(i.rep = 1:n_reps,
                      .errorhandling = 'pass') %dopar% {
  
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
save(all_results, file = paste0("raw_results_20reps_", scenarios[1], "_FULLY_FIXED.RData"))

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
    estimates <- sapply(scenario_results, function(x) x[[method]]$estimate)
    ses <- sapply(scenario_results, function(x) x[[method]]$se)
    ci_lowers <- sapply(scenario_results, function(x) x[[method]]$ci_lower)
    ci_uppers <- sapply(scenario_results, function(x) x[[method]]$ci_upper)
    
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
cat("Results saved to: raw_results_20reps_", scenarios[1], "_FULLY_FIXED.RData\n")
cat("============================================================\n")
EOF
    
    echo "✅ Created $SCRIPT"
done

echo ""
echo "All 20-rep test scripts created with FULLY FIXED WDSM!"
