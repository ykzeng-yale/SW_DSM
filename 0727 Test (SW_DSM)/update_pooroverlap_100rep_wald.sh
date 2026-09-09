#!/bin/bash

# Script to update all poor overlap scenarios to use correct WDSM with Normal Wald CI
# and submit 100-rep jobs to tong account

echo "==========================================
Updating Poor Overlap Scripts with Normal Wald CI WDSM
==========================================
"

# Define scenarios
SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")

# Create updated comparison script template
cat > temp_comparison_script.R << 'EOF'
# ==============================================================================
# PATE Retrospective - Poor Overlap
# Scenario: SCENARIO_PLACEHOLDER
# 100 Replications with CORRECTED WDSM using Normal Wald CI
# ==============================================================================

# Load required packages
library(tidyverse)
library(doParallel)
library(foreach)
library(MASS)
library(glmnet)

# Clear workspace
rm(list = ls())
gc()

# ============================================================================
# SOURCE FUNCTIONS - GLOBAL LEVEL
# ============================================================================

# Source dsmatch functions globally (Good Overlap approach)
source("dsmatch-master/R/distances_mvnorm.R")
source("dsmatch-master/R/distances_maha.R")
source("dsmatch-master/R/all_equal_to.R")
source("dsmatch-master/R/bisect.R")
source("dsmatch-master/R/is.lp.R")
source("dsmatch-master/R/is.pg.R")
source("dsmatch-master/R/is.ps.R")
source("dsmatch-master/R/dsmatchATE.R")  # Source last after dependencies

# Source WDSM functions with NORMAL WALD CI from main directory
source("../wdsm_method2_multinomial_bootstrap_WALD.R")
source("../wdsm_ci_functions.R")

# ============================================================================
# PARAMETERS
# ============================================================================

n_reps <- 100  # 100 replications
n_cores <- 12
n_sample <- 5000  # Correct sample size from original simulation
M <- 5  # Default M for matching
n_bootstrap <- 200
scenario <- "SCENARIO_PLACEHOLDER"

# ============================================================================
# LOAD POPULATION DATA
# ============================================================================

cat("Loading population data...\n")
load("../SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")

true_pate <- SuperPop_Poor$true_pate
cat("True Population PATE:", true_pate, "\n")
cat("Population size:", nrow(SuperPop_Poor$data), "\n")
cat("Sample size:", n_sample, "\n\n")

# ============================================================================
# RUN SIMULATION
# ============================================================================

# Setup parallel processing
cl <- makeCluster(n_cores, outfile = "parallel_output.txt")
registerDoParallel(cl)

cat("Starting simulation with", n_reps, "replicates using", n_cores, "cores\n")
cat("Scenario:", scenario, "\n")
cat("M value:", M, "\n")

# Function to run single replicate
run_single_replicate <- function(seed, scenario, pop_data, n_sample) {
  set.seed(seed)
  
  tryCatch({
    # Source functions inside worker (CRITICAL for PSOCK clusters)
    source("dsmatch-master/R/distances_mvnorm.R")
    source("dsmatch-master/R/distances_maha.R")
    source("dsmatch-master/R/all_equal_to.R")
    source("dsmatch-master/R/bisect.R")
    source("dsmatch-master/R/is.lp.R")
    source("dsmatch-master/R/is.pg.R")
    source("dsmatch-master/R/is.ps.R")
    source("dsmatch-master/R/dsmatchATE.R")
    
    # Source WDSM with Normal Wald CI
    source("../wdsm_method2_multinomial_bootstrap_WALD.R")
    source("../wdsm_ci_functions.R")
    
    # Retrospective sampling (using correct probability-based function)
    sample_data <- retrospective_sample(pop_data, n_sample)
    
    # Extract components
    Y <- sample_data$Y
    A <- sample_data$A
    sw <- sample_data$survey_weight
    
    # Define covariate matrices based on scenario
    if (scenario %in% c("CorCor", "MisCor")) {
      # PS correct: includes interaction
      X_ps <- as.matrix(sample_data[, c("X1", "X2", "X3", "X4", "X5", "X6", "X1X2")])
    } else {
      # PS misspecified: no interaction
      X_ps <- as.matrix(sample_data[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    }
    
    if (scenario %in% c("CorCor", "CorMis")) {
      # PG correct: includes interaction
      lp_pg <- as.matrix(sample_data[, c("X1", "X2", "X3", "X4", "X5", "X6", "X1X2")])
    } else {
      # PG misspecified: no interaction
      lp_pg <- as.matrix(sample_data[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    }
    
    # Base X for WDSM (always without interaction in X, but model spec controls inclusion)
    X_base <- as.matrix(sample_data[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    
    results <- list()
    
    # ============================
    # 1. Unweighted DSM
    # ============================
    tryCatch({
      dsm_result <- dsmatchATE(
        Y = Y,
        Tr = A,
        X = X_ps,
        lp.pg = lp_pg,
        weights = rep(1, length(Y)),
        estimand = "ATE",
        model.ps = "logit",
        model.pg = "glm",
        bootstrap = FALSE
      )
      
      # Bootstrap for SE
      boot_ests <- numeric(200)
      for (b in 1:200) {
        idx <- sample(1:length(Y), replace = TRUE)
        boot_res <- dsmatchATE(
          Y = Y[idx],
          Tr = A[idx],
          X = X_ps[idx,, drop=FALSE],
          lp.pg = lp_pg[idx,, drop=FALSE],
          weights = rep(1, length(idx)),
          estimand = "ATE",
          model.ps = "logit",
          model.pg = "glm",
          bootstrap = FALSE
        )
        boot_ests[b] <- boot_res$est.ds
      }
      
      se_dsm <- sd(boot_ests, na.rm = TRUE)
      ci_lower <- dsm_result$est.ds - 1.96 * se_dsm
      ci_upper <- dsm_result$est.ds + 1.96 * se_dsm
      
      results$dsm_unweighted <- list(
        estimate = dsm_result$est.ds,
        se = se_dsm,
        ci_lower = ci_lower,
        ci_upper = ci_upper
      )
    }, error = function(e) {
      results$dsm_unweighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    # ============================
    # 2. Unweighted PG Matching
    # ============================
    tryCatch({
      pg_result <- dsmatchATE(
        Y = Y,
        Tr = A,
        lp.pg = lp_pg,
        weights = rep(1, length(Y)),
        estimand = "ATE",
        model.pg = "glm",
        bootstrap = FALSE
      )
      
      # Bootstrap for SE
      boot_ests <- numeric(200)
      for (b in 1:200) {
        idx <- sample(1:length(Y), replace = TRUE)
        boot_res <- dsmatchATE(
          Y = Y[idx],
          Tr = A[idx],
          lp.pg = lp_pg[idx,, drop=FALSE],
          weights = rep(1, length(idx)),
          estimand = "ATE",
          model.pg = "glm",
          bootstrap = FALSE
        )
        boot_ests[b] <- boot_res$est.pg
      }
      
      se_pg <- sd(boot_ests, na.rm = TRUE)
      ci_lower <- pg_result$est.pg - 1.96 * se_pg
      ci_upper <- pg_result$est.pg + 1.96 * se_pg
      
      results$pg_unweighted <- list(
        estimate = pg_result$est.pg,
        se = se_pg,
        ci_lower = ci_lower,
        ci_upper = ci_upper
      )
    }, error = function(e) {
      results$pg_unweighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    # ============================
    # 3. Unweighted PS Matching
    # ============================
    tryCatch({
      ps_result <- dsmatchATE(
        Y = Y,
        Tr = A,
        X = X_ps,
        weights = rep(1, length(Y)),
        estimand = "ATE",
        model.ps = "logit",
        bootstrap = FALSE
      )
      
      # Bootstrap for SE
      boot_ests <- numeric(200)
      for (b in 1:200) {
        idx <- sample(1:length(Y), replace = TRUE)
        boot_res <- dsmatchATE(
          Y = Y[idx],
          Tr = A[idx],
          X = X_ps[idx,, drop=FALSE],
          weights = rep(1, length(idx)),
          estimand = "ATE",
          model.ps = "logit",
          bootstrap = FALSE
        )
        boot_ests[b] <- boot_res$est.ps
      }
      
      se_ps <- sd(boot_ests, na.rm = TRUE)
      ci_lower <- ps_result$est.ps - 1.96 * se_ps
      ci_upper <- ps_result$est.ps + 1.96 * se_ps
      
      results$ps_unweighted <- list(
        estimate = ps_result$est.ps,
        se = se_ps,
        ci_lower = ci_lower,
        ci_upper = ci_upper
      )
    }, error = function(e) {
      results$ps_unweighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    # ============================
    # 4. Survey-Weighted PS Full Matching (MatchIt)
    # ============================
    tryCatch({
      library(MatchIt)
      library(marginaleffects)
      
      # Normalize weights for MatchIt
      sw_norm <- sw * length(sw) / sum(sw)
      
      # Create formula based on scenario
      if (scenario %in% c("CorCor", "MisCor")) {
        # PS correct: includes interaction
        ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
      } else {
        # PS misspecified: no interaction
        ps_formula <- A ~ X1 + X2 + X3 + X4 + X5 + X6
      }
      
      # Perform matching
      m.out <- matchit(ps_formula, 
                      data = sample_data,
                      method = "full",
                      distance = "glm",
                      link = "logit",
                      s.weights = sw_norm,
                      estimand = "ATE")
      
      # Extract matched data
      m.data <- match.data(m.out)
      
      # Fit correctly specified outcome model (always correct for bias correction)
      fit <- lm(Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2), 
               data = m.data, 
               weights = weights * sw)
      
      # Get PATE with normalized weights
      comp <- avg_comparisons(fit, 
                              variables = "A",
                              vcov = ~subclass,
                              wts = "sw",
                              newdata = m.data)
      
      results$ps_weighted <- list(
        estimate = comp$estimate,
        se = comp$std.error,
        ci_lower = comp$conf.low,
        ci_upper = comp$conf.high
      )
    }, error = function(e) {
      results$ps_weighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    # ============================
    # 5. WDSM with Normal Wald CI
    # ============================
    tryCatch({
      # Create data with scenario-specific model specifications
      wdsm_data <- sample_data[, c("Y", "A", "X1", "X2", "X3", "X4", "X5", "X6")]
      
      # Add interaction term based on scenario
      if (scenario %in% c("CorCor", "MisCor")) {
        # For PS estimation
        X_wdsm_ps <- cbind(X_base, X_base[,1] * X_base[,2])
      } else {
        X_wdsm_ps <- X_base
      }
      
      # WDSM uses Normal Wald CI via our updated function
      ci_results <- compute_wdsm_method2_ci(
        Y = Y, 
        A = A, 
        X = X_base,  # Base X for WDSM
        weights = sw,
        M = M,
        n_bootstrap = n_bootstrap,
        alpha = 0.05,
        use_bias_correction = TRUE,
        return_samples = FALSE
      )
      
      results$wdsm_multinomial <- list(
        estimate = ci_results$estimate,
        se = ci_results$se,
        ci_lower = ci_results$ci_lower,
        ci_upper = ci_results$ci_upper
      )
    }, error = function(e) {
      results$wdsm_multinomial <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    return(results)
    
  }, error = function(e) {
    return(list(
      dsm_unweighted = list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA),
      pg_unweighted = list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA),
      ps_unweighted = list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA),
      ps_weighted = list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA),
      wdsm_multinomial = list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA),
      error = as.character(e)
    ))
  })
}

# Run simulation
start_time <- Sys.time()

all_results <- foreach(i.rep = 1:n_reps, 
                       .combine = 'c',
                       .packages = c("dplyr", "MASS", "glmnet", "MatchIt", "marginaleffects"),
                       .export = c("run_single_replicate", "scenario", "n_sample", "M", 
                                  "n_bootstrap", "true_pate", "SuperPop_Poor",
                                  "retrospective_sample", "wdsm_point_estimate",
                                  "method2_multinomial_bootstrap_ci",
                                  "expit", "weighted_distance", "find_weighted_neighbors",
                                  "calculate_weighted_reuse_counts", "compute_wdsm_method2_ci")) %dopar% {
  
  # Progress tracking
  if (i.rep %% 20 == 0) {
    cat("Completed replicate", i.rep, "of", n_reps, "\n")
  }
  
  list(run_single_replicate(seed = 2024 + i.rep, 
                           scenario = scenario,
                           pop_data = SuperPop_Poor$data, 
                           n_sample = n_sample))
}

stopCluster(cl)

end_time <- Sys.time()
runtime <- as.numeric(difftime(end_time, start_time, units = "mins"))

# Process results
n_successful <- sum(!sapply(all_results, function(x) is.null(x) || length(x) == 0))
cat("\nSuccessful runs:", n_successful, "out of", n_reps, "\n")

# Calculate summary statistics
methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", "wdsm_multinomial")
summary_stats <- data.frame(
  Method = methods,
  Bias = NA, SE = NA, Coverage = NA, RMSE = NA
)

for (i in 1:length(methods)) {
  method <- methods[i]
  estimates <- sapply(all_results, function(x) x[[method]]$estimate)
  ses <- sapply(all_results, function(x) x[[method]]$se)
  ci_lowers <- sapply(all_results, function(x) x[[method]]$ci_lower)
  ci_uppers <- sapply(all_results, function(x) x[[method]]$ci_upper)
  
  # Remove NAs
  valid_idx <- !is.na(estimates) & !is.na(ci_lowers) & !is.na(ci_uppers)
  estimates <- estimates[valid_idx]
  ses <- ses[valid_idx]
  ci_lowers <- ci_lowers[valid_idx]
  ci_uppers <- ci_uppers[valid_idx]
  
  if (length(estimates) > 0) {
    # Relative bias (%)
    bias <- 100 * (mean(estimates) - true_pate) / true_pate
    
    # Empirical SE
    emp_se <- sd(estimates)
    
    # SE ratio
    mean_se <- mean(ses, na.rm = TRUE)
    se_ratio <- mean_se / emp_se
    
    # Coverage
    coverage <- 100 * mean(ci_lowers <= true_pate & ci_uppers >= true_pate)
    
    # RMSE
    rmse <- sqrt(mean((estimates - true_pate)^2))
    
    summary_stats[i, ] <- c(method, 
                           round(bias, 3), 
                           round(se_ratio, 3), 
                           round(coverage, 1),
                           round(rmse, 3))
  }
}

# Print results
cat("\n", paste(rep("=", 60), collapse = ""), "\n", sep = "")
cat("RESULTS SUMMARY (", n_successful, " replicates)\n")
cat("True PATE:", true_pate, "\n")
cat(paste(rep("=", 60), collapse = ""), "\n")
cat(sprintf("%-24s %7s %7s %8s %8s\n", "Method", "Bias", "SE", "Coverage", "RMSE"))
cat(paste(rep("-", 60), collapse = ""), "\n")
for (i in 1:nrow(summary_stats)) {
  cat(sprintf("%-24s %7s %7s %8s %8s\n",
             summary_stats$Method[i],
             summary_stats$Bias[i],
             summary_stats$SE[i],
             summary_stats$Coverage[i],
             summary_stats$RMSE[i]))
}

# Save results
save(all_results, summary_stats, scenario, n_reps, true_pate, runtime,
     file = paste0("raw_results_100reps_", scenario, "_WALD_CI.RData"))

cat("\n", paste(rep("=", 60), collapse = ""), "\n", sep = "")
cat("Simulation completed in", round(runtime, 1), "minutes\n")
cat("Results saved to: raw_results_100reps_", scenario, "_WALD_CI.RData\n")
cat(paste(rep("=", 60), collapse = ""), "\n")
EOF

# Update each scenario folder
for scenario in "${SCENARIOS[@]}"; do
    echo "Updating $scenario..."
    
    # Create scenario-specific script
    sed "s/SCENARIO_PLACEHOLDER/$scenario/g" temp_comparison_script.R > \
        "PATE Retrospective Pooroverlap M135 $scenario GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    echo "✅ Created comparison script for $scenario"
done

# Clean up
rm temp_comparison_script.R

echo "
==========================================
All scripts updated with Normal Wald CI!
Ready to submit 100-rep jobs to tong account
==========================================
"
