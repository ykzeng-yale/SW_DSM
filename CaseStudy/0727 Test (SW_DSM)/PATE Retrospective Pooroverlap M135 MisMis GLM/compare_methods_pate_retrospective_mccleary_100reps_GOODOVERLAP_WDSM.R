#!/usr/bin/env Rscript
################################################################################
# 100-REPLICATION Production Run with GOOD OVERLAP WDSM Functions
# PATE Retrospective - Poor Overlap Scenario: MisMis
# Using EXACT SAME WDSM as good overlap scenarios
################################################################################

library(doParallel)
library(foreach)
library(tidyverse)
library(glmnet)
library(MatchIt)
library(marginaleffects)

# Set working directory to project root
setwd("/gpfs/gibbs/project/tong/yz2324/pooroverlap_100rep_goodwdsm")

# Set up parallel processing
n_cores <- 12
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

cat("\n============================================================\n")
cat("100-REP Production Run with GOOD OVERLAP WDSM\n")
cat("Scenario: MisMis\n")
cat("============================================================\n\n")

# Load the poor overlap population data
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")

# Use the original simulation's retrospective sampling function
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  c0 <- log(n_sample/N / (1 - n_sample/N))
  c1 <- log(1.05)
  c2 <- log(1.10)
  c3 <- log(1.15)
  c4 <- log(1.10)
  c5 <- log(1.05)
  c6 <- log(1.10)
  delta_z_in_s <- log(0.9)
  
  formula_S <- c0 + delta_z_in_s * population$A +
               c1 * population$X1 + c2 * population$X2 +
               c3 * population$X3 + c4 * population$X4 +
               c5 * population$X5 + c6 * population$X6
  
  prob_S <- exp(formula_S) / (1 + exp(formula_S))
  population$Prob <- prob_S
  population$S <- rbinom(N, 1, prob_S)
  
  sample_data <- population[population$S == 1, ]
  sample_data$survey_weight <- 1 / sample_data$Prob
  
  return(sample_data)
}

# Source GOOD OVERLAP WDSM functions (from main directory)
source("../wdsm_method2_multinomial_bootstrap.R")
source("../wdsm_ci_functions.R")

cat("GOOD OVERLAP WDSM functions loaded successfully.\n")

# Global sourcing of dsmatch functions
source("dsmatch-master/R/utils.R")
source("dsmatch-master/R/standardize.R")
source("dsmatch-master/R/adacalipers.R")
source("dsmatch-master/R/wave_selection.R")
source("dsmatch-master/R/matching.R")
source("dsmatch-master/R/wfunc.R")
source("dsmatch-master/R/estimate.R")
source("dsmatch-master/R/bootstrap.R")
source("dsmatch-master/R/dsmatchATE.R")

# Simulation parameters
n_reps <- 100
n_sample <- 5000
M <- 5
B <- 200
scenario <- "MisMis"

cat("\nConfiguration:\n")
cat(sprintf("- Sample size: n=%d\n", n_sample))
cat(sprintf("- Scenario: %s\n", scenario))
cat(sprintf("- Replicates: %d\n", n_reps))
cat(sprintf("- Bootstrap: %d\n", B))
cat(sprintf("- M: %d\n", M))
cat("- All 5 methods enabled\n")
cat("- Account: tong\n")

# Function to run a single replicate
run_single_replicate <- function(rep_id, population, n_sample, scenario, M, B) {
  
  tryCatch({
    # Source required functions inside worker
    # Source GOOD OVERLAP WDSM functions
    source("../wdsm_method2_multinomial_bootstrap.R")
    source("../wdsm_ci_functions.R")
    
    # Source dsmatch functions in correct order
    source("dsmatch-master/R/utils.R")
    source("dsmatch-master/R/standardize.R")
    source("dsmatch-master/R/adacalipers.R")
    source("dsmatch-master/R/wave_selection.R")
    source("dsmatch-master/R/matching.R")
    source("dsmatch-master/R/wfunc.R")
    source("dsmatch-master/R/estimate.R")
    source("dsmatch-master/R/bootstrap.R")
    source("dsmatch-master/R/dsmatchATE.R")
    
    # Sample data using retrospective sampling
    sample_data <- retrospective_sample(population, n_sample)
    
    # Prepare data
    Y <- sample_data$Y
    A <- sample_data$A
    X <- as.matrix(sample_data[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    sw <- sample_data$survey_weight
    
    # Setup model specifications for CorCor scenario
    # MisMis: Both PS and PG models misspecified (no interaction)
    X_ps <- X  # No interaction (misspecified)
    # No interaction column for PS
    X_pg <- X  # No interaction (misspecified)
    # No interaction column for PG
    
    results <- list()
    
    # Method 1: Unweighted DSM (NO M parameter!)
    tryCatch({
      dsm_result <- dsmatchATE(
        Y = Y,
        A = A,
        X = X_ps,
        lp.pg = X_pg,
        model.ps = "logit",
        model.pg = "glm",
        bootstrap = 200
      )
      
      results$dsm_unweighted <- list(
        estimate = dsm_result$est.ds,
        se = sqrt(dsm_result$bootvar[1,1]),
        ci_lower = dsm_result$est.ds - 1.96 * sqrt(dsm_result$bootvar[1,1]),
        ci_upper = dsm_result$est.ds + 1.96 * sqrt(dsm_result$bootvar[1,1])
      )
    }, error = function(e) {
      results$dsm_unweighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    # Method 2: Unweighted PG matching (NO M parameter!)
    tryCatch({
      pg_result <- dsmatchATE(
        Y = Y,
        A = A,
        X = X_ps,
        lp.pg = X_pg,
        model.ps = "logit",
        model.pg = "glm",
        estimand = "ATE",
        method = "pg",
        bootstrap = 200
      )
      
      results$pg_unweighted <- list(
        estimate = pg_result$est.pg,
        se = sqrt(pg_result$bootvar[2,2]),
        ci_lower = pg_result$est.pg - 1.96 * sqrt(pg_result$bootvar[2,2]),
        ci_upper = pg_result$est.pg + 1.96 * sqrt(pg_result$bootvar[2,2])
      )
    }, error = function(e) {
      results$pg_unweighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    # Method 3: Unweighted PS matching (NO M parameter!)
    tryCatch({
      ps_result <- dsmatchATE(
        Y = Y,
        A = A,
        X = X_ps,
        lp.pg = X_pg,
        model.ps = "logit",
        model.pg = "glm",
        estimand = "ATE",
        method = "ps",
        bootstrap = 200
      )
      
      results$ps_unweighted <- list(
        estimate = ps_result$est.ps,
        se = sqrt(ps_result$bootvar[3,3]),
        ci_lower = ps_result$est.ps - 1.96 * sqrt(ps_result$bootvar[3,3]),
        ci_upper = ps_result$est.ps + 1.96 * sqrt(ps_result$bootvar[3,3])
      )
    }, error = function(e) {
      results$ps_unweighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    # Method 4: Survey-weighted PS Full matching
    tryCatch({
      # Normalize weights as MatchIt expects
      sw_normalized <- sw * length(sw) / sum(sw)
      
      # Fit propensity score model with survey weights
      ps_model <- glm(A ~ X1 + X2 + X3 + X4 + X5 + X6,
                      data = sample_data,
                      family = binomial(link = "logit"),
                      weights = sw_normalized)
      
      # Perform full matching with survey weights
      match_full <- matchit(A ~ X1 + X2 + X3 + X4 + X5 + X6,
                            data = sample_data,
                            method = "full",
                            distance = "glm",
                            link = "logit",
                            s.weights = sw_normalized,
                            estimand = "ATE")
      
      # Extract matched data
      matched_data <- match.data(match_full)
      
      # Fit outcome model with interaction (correctly specified for CorCor)
      outcome_model <- lm(Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2),
                         data = matched_data,
                         weights = weights * sw)
      
      # Calculate PATE with normalized weights
      comp <- avg_comparisons(outcome_model,
                              variables = "A",
                              vcov = ~subclass,
                              wts = "sw",
                              comparison = "difference",
                              transform = NULL)
      
      results$ps_weighted <- list(
        estimate = comp$estimate,
        se = comp$std.error,
        ci_lower = comp$conf.low,
        ci_upper = comp$conf.high
      )
    }, error = function(e) {
      results$ps_weighted <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    # Method 5: WDSM with multinomial bootstrap (GOOD OVERLAP VERSION)
    tryCatch({
      # Calculate point estimate
      wdsm_est <- wdsm_point_estimate(
        Y = Y,
        A = A,
        X = X,
        weights = sw,
        M = M,
        include_interaction_ps = (scenario %in% c("CorCor", "CorMis")),
        include_interaction_pg = (scenario %in% c("CorCor", "MisCor"))
      )
      
      # Calculate CI using method 2 (multinomial bootstrap)
      wdsm_ci <- compute_wdsm_method2_ci(
        Y = Y,
        A = A,
        X = X,
        weights = sw,
        point_estimate = wdsm_est,
        M = M,
        B = B,
        include_interaction_ps = (scenario %in% c("CorCor", "CorMis")),
        include_interaction_pg = (scenario %in% c("CorCor", "MisCor"))
      )
      
      results$wdsm_multinomial <- list(
        estimate = wdsm_est,
        se = wdsm_ci$se,
        ci_lower = wdsm_ci$ci_lower,
        ci_upper = wdsm_ci$ci_upper
      )
    }, error = function(e) {
      results$wdsm_multinomial <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    })
    
    return(results)
    
  }, error = function(e) {
    cat(sprintf("Error in replicate %d: %s\n", rep_id, e$message))
    return(NULL)
  })
}

# Load population and get true PATE
true_pate <- mean(Super_Population_PoorOverlap$Y1 - Super_Population_PoorOverlap$Y0)
cat(sprintf("\nTrue Population PATE: %.4f\n", true_pate))
cat(sprintf("Population size: %d\n", nrow(Super_Population_PoorOverlap)))
cat(sprintf("Sample size: %d\n", n_sample))

# Run simulation
cat("\n============================================================\n")
cat(sprintf("Starting simulation with %d replicates using %d cores\n", n_reps, n_cores))
cat(sprintf("Scenario: %s\n", scenario))
cat(sprintf("M value: %d\n", M))
cat("============================================================\n\n")

start_time <- Sys.time()

# Run parallel simulation with progress reporting
batch_size <- 10
n_batches <- ceiling(n_reps / batch_size)

all_results <- list()

for(batch in 1:n_batches) {
  batch_start <- (batch - 1) * batch_size + 1
  batch_end <- min(batch * batch_size, n_reps)
  batch_ids <- batch_start:batch_end
  
  cat(sprintf("Processing batch %d/%d (replicates %d-%d)...\n", 
              batch, n_batches, batch_start, batch_end))
  
  batch_results <- foreach(
    rep_id = batch_ids,
    .combine = 'c',
    .errorhandling = 'pass',
    .packages = c('glmnet', 'MatchIt', 'marginaleffects'),
    .export = c('run_single_replicate', 'retrospective_sample',
                'wdsm_point_estimate', 'compute_wdsm_method2_ci',
                'method2_multinomial_bootstrap_ci')
  ) %dopar% {
    list(run_single_replicate(rep_id, Super_Population_PoorOverlap, n_sample, scenario, M, B))
  }
  
  all_results <- c(all_results, batch_results)
  
  # Report progress
  successful <- sum(sapply(batch_results, function(x) !is.null(x)))
  cat(sprintf("  Batch %d completed: %d successful\n", batch, successful))
  gc()
}

end_time <- Sys.time()
runtime <- difftime(end_time, start_time, units = "mins")

# Stop cluster
stopCluster(cl)

# Filter out NULL results
valid_results <- all_results[!sapply(all_results, is.null)]
n_successful <- length(valid_results)

cat("\n============================================================\n")
cat(sprintf("Simulation completed in %.1f minutes\n", runtime))
cat("============================================================\n\n")
cat(sprintf("Successful runs: %d out of %d\n\n", n_successful, n_reps))

# Extract and analyze results
methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", "wdsm_multinomial")

# Initialize storage
estimates <- matrix(NA, n_successful, length(methods))
ses <- matrix(NA, n_successful, length(methods))
coverages <- matrix(NA, n_successful, length(methods))

colnames(estimates) <- methods
colnames(ses) <- methods
colnames(coverages) <- methods

# Extract results
for(i in 1:n_successful) {
  for(method in methods) {
    if(!is.null(valid_results[[i]][[method]])) {
      estimates[i, method] <- valid_results[[i]][[method]]$estimate
      ses[i, method] <- valid_results[[i]][[method]]$se
      ci_lower <- valid_results[[i]][[method]]$ci_lower
      ci_upper <- valid_results[[i]][[method]]$ci_upper
      coverages[i, method] <- (true_pate >= ci_lower) & (true_pate <= ci_upper)
    }
  }
}

# Calculate summary statistics
summary_stats <- data.frame(
  Method = methods,
  Bias = colMeans(estimates - true_pate, na.rm = TRUE),
  RelBias = 100 * colMeans(estimates - true_pate, na.rm = TRUE) / true_pate,
  EmpSE = apply(estimates, 2, sd, na.rm = TRUE),
  MeanSE = colMeans(ses, na.rm = TRUE),
  SERatio = colMeans(ses, na.rm = TRUE) / apply(estimates, 2, sd, na.rm = TRUE),
  Coverage = 100 * colMeans(coverages, na.rm = TRUE),
  RMSE = sqrt(colMeans((estimates - true_pate)^2, na.rm = TRUE))
)

# Calculate relative efficiency (using ps_unweighted as reference)
ref_var <- var(estimates[, "ps_unweighted"], na.rm = TRUE)
summary_stats$RelEff <- ref_var / apply(estimates, 2, var, na.rm = TRUE)

# Print results
cat("============================================================\n")
cat(sprintf("RESULTS SUMMARY (%d replicates)\n", n_successful))
cat(sprintf("True PATE: %.4f\n", true_pate))
cat("============================================================\n")
cat(sprintf("%-20s %8s %8s %8s %8s\n", "Method", "Bias", "SE", "Coverage", "RMSE"))
cat("------------------------------------------------------------\n")

for(i in 1:nrow(summary_stats)) {
  cat(sprintf("%-20s %8.3f %8.3f %8.2f %8.3f\n",
              summary_stats$Method[i],
              summary_stats$RelBias[i],
              summary_stats$SERatio[i],
              summary_stats$Coverage[i],
              summary_stats$RMSE[i]))
}

# Save results
results_list <- list(
  estimates = estimates,
  standard_errors = ses,
  coverages = coverages,
  summary_stats = summary_stats,
  true_pate = true_pate,
  n_reps = n_reps,
  n_successful = n_successful,
  n_sample = n_sample,
  scenario = scenario,
  M = M,
  runtime = runtime,
  raw_results = valid_results
)

filename <- sprintf("raw_results_100reps_%s_GOODOVERLAP_WDSM.RData", scenario)
save(results_list, file = filename)

cat("\n============================================================\n")
cat("100-REP RUN COMPLETE!\n")
cat(sprintf("Results saved to: %s\n", filename))
cat("============================================================\n")
