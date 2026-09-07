#!/usr/bin/env Rscript

##############################################################################
# PATE Retrospective Sampling - Model Misspecification Analysis (FIXED)
# M = 5, 1000 replications
# Comparing methods under 4 scenarios:
# - CorCor: Both PS and PGS correct
# - MisCor: PS misspecified, PGS correct  
# - CorMis: PS correct, PGS misspecified
# - MisMis: Both PS and PGS misspecified
#
# Methods compared:
# 1. Unweighted Double Score Matching (DSM)
# 2. Unweighted Prognostic Score Matching (PG)
# 3. Unweighted Propensity Score Matching (PS)
# 4. Survey-weighted Propensity Score Full Matching (MatchIt)
# 5. WDSM with Multinomial Bootstrap for retrospective sampling
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
library(R.utils)  # For withTimeout

# Source required functions
cat("Sourcing custom functions...\n")

# Source ALL necessary dsmatch functions
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

# ============================================================================
# Configuration
# ============================================================================
set.seed(2025)
n_reps <- 1000
n_sample <- 5000
M_values <- c(1, 3, 5)  # Single M value
B <- 200  # Bootstrap iterations
alpha <- 0.05
scenarios <- c("MisMis")  # Will be overridden by environment variable if set

# Check for environment variable to specify scenario
if (Sys.getenv("SCENARIO") != "") {
  scenarios <- Sys.getenv("SCENARIO")
  cat("Running scenario from environment:", scenarios, "\n")
}

# ============================================================================
# Load Population Data
# ============================================================================
cat("\n============================================================\n")
cat("Loading population data...\n")
cat("============================================================\n")

if (!exists("population")) load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")

# Preprocess raw population data to expected format
if (!exists("population")) {
  raw_pop <- SuperPopGen_GoodOverlap_AllinOne_0118_2025[[1]]
  population <- data.frame(
    X1 = raw_pop$x1, X2 = raw_pop$x2, X3 = raw_pop$x3,
    X4 = raw_pop$x4, X5 = raw_pop$x5, X6 = raw_pop$x6,
    A = raw_pop$z, Y_0 = raw_pop$y0, Y_1 = raw_pop$y1, Y_obs = raw_pop$y,
    Cluster = raw_pop$Cluster, Strata = raw_pop$Strata
  )
  population$S <- 1
  rm(raw_pop, SuperPopGen_GoodOverlap_AllinOne_0118_2025); gc()
  cat("Population preprocessed: n =", nrow(population), "\n")
}

# Calculate true PATE
true_pate <- mean(population$Y_1[population$S == 1]) - mean(population$Y_0[population$S == 1])
cat("\nTrue Population PATE:", round(true_pate, 4), "\n")

# Pre-compute retrospective sample for consistency
set.seed(2025)
population_S1 <- population[population$S == 1, ]
n_pop_S1 <- nrow(population_S1)
treated_indices_S1 <- which(population_S1$A == 1)
control_indices_S1 <- which(population_S1$A == 0)

# ============================================================================
# Function to run a single replicate (now loops over M values and scenarios)
# ============================================================================
run_single_replicate <- function(i.rep, seed_offset = 0) {
  set.seed(2025 + seed_offset + i.rep)
  
  # Apply timeout for entire replicate
  R.utils::withTimeout({
    # Prospective multi-stage sampling (independent of treatment)
    # Matching exactly SW_PSW-main/Sampling_MultiStage_and_Estimation.R
    population$ones <- 1
    population$id <- 1:nrow(population)
    size1 <- rep(100000, 10)
    size2 <- rep(5, 10)
    size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5),
               rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5),
               rep(250/5, 5), rep(150/5, 5))
    s_design <- sampling::mstage(population,
                                  stage = list("stratified", "cluster", ""),
                                  varnames = list("Strata", "Cluster", "ones"),
                                  size = list(size1, size2, size3),
                                  method = list("", "srswor", "srswor"))
    sample_data <- sampling::getdata(population, s_design)[[3]]
    sample_data$survey_weight <- 1 / sample_data$Prob
    
    Y <- sample_data$Y_obs
    A <- sample_data$A
    X <- as.matrix(sample_data[, c("X1", "X2", "X3", "X4", "X5", "X6")])
    colnames(X) <- c("X1", "X2", "X3", "X4", "X5", "X6")
    w_raw <- sample_data$survey_weight
    
    # Store results for all scenarios and M values
    replicate_results <- list()
    
    # Loop over scenarios
    for (scenario in scenarios) {
      # Loop over M values
      for (M in M_values) {
      # Determine which models use interaction term based on scenario
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
      
      # Create data frame for methods that need it
      df_data <- data.frame(Y = Y, A = A, X)
      
      # Initialize results storage for this M value
      m_results <- list()
      
      # ============================================================
      # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch-master)
      # ============================================================
      tryCatch({
        # Run DSM with bootstrap
        dsm_result <- dsmatchATE(
          Y = Y,
          X = X_ps,  # PS model uses X_ps (with/without interaction)
          A = A,
          method = "dsm",
          model.ps = "logit",  # Always logit for PS
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
        cat("DSM Unweighted Error in replicate", i.rep, ", scenario", scenario, ", M=", M, ":", e$message, "\n")
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
        # Run PG matching with bootstrap
        pg_result <- dsmatchATE(
          Y = Y,
          X = X_pg,  # PG model uses X_pg (with/without interaction)
          A = A,
          method = "pg",
          model.pg = "glm",  # Always glm for PG
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
        cat("PG Unweighted Error in replicate", i.rep, ", scenario", scenario, ", M=", M, ":", e$message, "\n")
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
        # Run PS matching with bootstrap using dsmatch-master
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
        cat("PS Unweighted Error in replicate", i.rep, ", scenario", scenario, ", M=", M, ":", e$message, "\n")
        m_results$ps_unweighted <- list(
          estimate = NA,
          se = NA,
          ci_lower = NA,
          ci_upper = NA
        )
      })
      
      # ============================================================
      # METHOD 4: SURVEY-WEIGHTED PROPENSITY SCORE FULL MATCHING (MatchIt)
      # ============================================================
      tryCatch({
        # Normalize survey weights for MatchIt s.weights
        n_sw <- length(w_raw)
        sw_norm <- w_raw * n_sw / sum(w_raw)
        
        # Add normalized survey weights to data frame
        df_data$sw <- sw_norm
        
        # PS formula based on scenario
        ps_formula <- if (use_interaction_ps) {
          A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
        } else {
          A ~ X1 + X2 + X3 + X4 + X5 + X6
        }
        
        # Full matching with survey weights in PS estimation
        m_ps_sw <- matchit(ps_formula,
                          data = df_data,
                          method = "full",
                          distance = "glm",
                          link = "logit",
                          estimand = "ATE",
                          s.weights = df_data$sw,
                          verbose = FALSE)
        
        # match.data returns weights = matching_weights * s.weights
        md_sw <- match.data(m_ps_sw)
        
        # Outcome model always correctly specified (not subject to misspec scenarios)
        # Fit with MatchIt combined weights (matching x survey)
        outcome_formula <- Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2)
        fit_sw <- lm(outcome_formula,
                    data = md_sw,
                    weights = weights)
        
        # ATE via marginaleffects with MatchIt combined weights
        ate_sw <- avg_comparisons(fit_sw, newdata = md_sw, 
                                  variables = "A",
                                  vcov = ~subclass,
                                  wts = "sw")
        
        m_results$ps_weighted <- list(
          estimate = ate_sw$estimate,
          se = ate_sw$std.error,
          ci_lower = ate_sw$conf.low,
          ci_upper = ate_sw$conf.high
        )
        
      }, error = function(e) {
        cat("PS Weighted Error in replicate", i.rep, ", scenario", scenario, ", M=", M, ":", e$message, "\n")
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
        # WDSM always uses the scenario-specific covariate sets
        # Pass the appropriate X matrix for the scenario
        ci_results <- compute_wdsm_method2_ci(
          Y = Y, 
          A = A, 
          X = X,  # Base X without interaction
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
    
    # Remove time limit
    setTimeLimit(cpu = Inf, elapsed = Inf)
    
    return(replicate_results)
    
  }, timeout = 900, onTimeout = "error")  # 15 minutes timeout per replicate
}

# ============================================================================
# Run Main Simulation
# ============================================================================
cat("\n============================================================\n")
cat("Running PATE Retrospective Sampling Comparison\n")
cat("With Model Misspecification Scenarios\n")
cat("============================================================\n")

cat("\nSample size:", n_sample, "\n")
cat("Number of replicates:", n_reps, "\n")
cat("Number of matches (M values):", M_values, "\n")
cat("Bootstrap iterations:", B, "\n")
cat("Significance level:", alpha, "\n")
cat("Model scenarios:", paste(scenarios, collapse = ", "), "\n")

# Setup parallel processing
cat("\n============================================================\n")
cat("Setting up parallel backend with", detectCores() - 2, "cores (FORK cluster)...\n")
cat("============================================================\n")

n_cores <- min(detectCores() - 2, 30)  # Use up to 30 cores
cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

# Export necessary objects to parallel workers (even for FORK, to be safe)
clusterExport(cl, c("run_single_replicate", "population", "true_pate",
                    "n_sample", "M_values", "B", "alpha", "scenarios",
                    "retrospective_sample", "wdsm_point_estimate", 
                    "method2_multinomial_bootstrap_ci", "expit",
                    "weighted_distance", "find_weighted_neighbors",
                    "compute_wdsm_method2_ci"))

# Run simulation with batching
cat("\nRunning simulation in batches of 100 replicates each...\n")
cat("============================================================\n")

batch_size <- 100
n_batches <- ceiling(n_reps / batch_size)

start_time <- Sys.time()
all_results <- list()

for (batch in 1:n_batches) {
  batch_start <- (batch - 1) * batch_size + 1
  batch_end <- min(batch * batch_size, n_reps)
  batch_indices <- batch_start:batch_end
  
  cat("\nProcessing batch", batch, "of", n_batches, 
      "(replicates", batch_start, "to", batch_end, ")...\n")
  
  batch_results <- foreach(i = batch_indices, 
                          .errorhandling = 'pass',
                          .maxcombine = batch_size,
                          .verbose = FALSE) %dopar% {
    run_single_replicate(i)
  }
  
  all_results <- c(all_results, batch_results)
  
  # Force garbage collection
  gc()
}

# Stop cluster
stopCluster(cl)

end_time <- Sys.time()
runtime <- difftime(end_time, start_time, units = "mins")

cat("\n============================================================\n")
cat("Simulation completed in", round(runtime, 2), "minutes\n")
cat("============================================================\n")

# CRITICAL: Save raw results immediately before processing
cat("\n============================================================\n")
cat("Saving raw simulation results...\n")
cat("============================================================\n")

save(all_results, n_reps, n_sample, M_values, B, alpha, scenarios, true_pate,
     file = paste0("raw_results_", scenarios[1], "_M", paste0(M_values, collapse=""), "_", n_reps, "rep.RData"))

cat("Raw results saved successfully!\n")

# ============================================================================
# Process Results (with fix for sapply issue)
# ============================================================================
cat("\n============================================================\n")
cat("Processing simulation results...\n")
cat("============================================================\n")

# Function to safely extract numeric values
safe_extract <- function(x) {
  if (is.null(x)) return(NA)
  if (is.list(x)) {
    if (length(x) > 0) return(x[[1]])
    return(NA)
  }
  return(x)
}

# Count successful runs
successful_runs <- sum(sapply(all_results, function(x) !is.null(x) && !inherits(x, "error") && !"error" %in% names(x)))
cat("\nSuccessful runs:", successful_runs, "out of", n_reps, "\n")

# Filter out failed runs
valid_results <- all_results[sapply(all_results, function(x) !is.null(x) && !inherits(x, "error") && !"error" %in% names(x))]

if (length(valid_results) == 0) {
  stop("No successful simulation runs!")
}

# Initialize storage for processed results
results_by_scenario_m <- list()

# Process results for each scenario and M combination
for (scenario in scenarios) {
  for (M in M_values) {
    key <- paste0(scenario, "_M", M)
    
    # Extract results for this scenario and M
    scenario_m_results <- lapply(valid_results, function(x) x[[key]])
    
    # Remove NULL results
    scenario_m_results <- scenario_m_results[!sapply(scenario_m_results, is.null)]
    
    if (length(scenario_m_results) > 0) {
      # Calculate metrics for each method
      methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", "wdsm_multinomial")
      
      method_stats <- list()
      for (method in methods) {
        # Use unlist and safe extraction
        estimates <- unlist(lapply(scenario_m_results, function(x) safe_extract(x[[method]]$estimate)))
        ses <- unlist(lapply(scenario_m_results, function(x) safe_extract(x[[method]]$se)))
        ci_lowers <- unlist(lapply(scenario_m_results, function(x) safe_extract(x[[method]]$ci_lower)))
        ci_uppers <- unlist(lapply(scenario_m_results, function(x) safe_extract(x[[method]]$ci_upper)))
        
        # Convert to numeric and remove NAs
        estimates <- as.numeric(estimates[!is.na(estimates)])
        ses <- as.numeric(ses[!is.na(ses)])
        ci_lowers <- as.numeric(ci_lowers[!is.na(ci_lowers)])
        ci_uppers <- as.numeric(ci_uppers[!is.na(ci_uppers)])
        
        if (length(estimates) > 0) {
          method_stats[[method]] <- list(
            n_valid = length(estimates),
            mean_estimate = mean(estimates),
            bias = mean(estimates) - true_pate,
            rel_bias = (mean(estimates) - true_pate) / abs(true_pate),
            empirical_se = sd(estimates),
            mean_se = mean(ses),
            se_ratio = mean(ses) / sd(estimates),
            coverage = mean(ci_lowers <= true_pate & ci_uppers >= true_pate),
            rmse = sqrt(mean((estimates - true_pate)^2))
          )
        }
      }
      
      results_by_scenario_m[[key]] <- method_stats
    }
  }
}

# ============================================================================
# Display Results
# ============================================================================
cat("\n============================================================\n")
cat("SIMULATION RESULTS SUMMARY\n")
cat("============================================================\n")

library(dplyr)
library(tidyr)
library(purrr)

# Convert results to data frame for better display
results_df_list <- list()

for (key in names(results_by_scenario_m)) {
  scenario_m <- strsplit(key, "_M")[[1]]
  scenario <- scenario_m[1]
  M <- as.numeric(scenario_m[2])
  
  for (method_name in names(results_by_scenario_m[[key]])) {
    stats <- results_by_scenario_m[[key]][[method_name]]
    
    if (!is.null(stats)) {
      results_df_list[[length(results_df_list) + 1]] <- data.frame(
        Scenario = scenario,
        M = M,
        Method = switch(method_name,
                       "dsm_unweighted" = "DSM Unweighted",
                       "pg_unweighted" = "PG Unweighted",
                       "ps_unweighted" = "PS Unweighted",
                       "ps_weighted" = "PS Full (MatchIt)",
                       "wdsm_multinomial" = "WDSM Multinomial"),
        N_Valid = stats$n_valid,
        Mean_Estimate = round(stats$mean_estimate, 4),
        Bias = round(stats$bias, 4),
        Rel_Bias = round(stats$rel_bias * 100, 3),
        Empirical_SE = round(stats$empirical_se, 4),
        Mean_SE = round(stats$mean_se, 4),
        SE_Ratio = round(stats$se_ratio, 3),
        Coverage = round(stats$coverage * 100, 1),
        RMSE = round(stats$rmse, 4)
      )
    }
  }
}

# Combine all results
if (length(results_df_list) > 0) {
  results_df <- do.call(rbind, results_df_list)
  
  # Display results by scenario
  for (scenario in unique(results_df$Scenario)) {
    cat("\n------------------------------------------------------------\n")
    cat("Scenario:", scenario, "\n")
    cat("------------------------------------------------------------\n")
    
    scenario_df <- results_df[results_df$Scenario == scenario, ]
    print(scenario_df[, c("Method", "Rel_Bias", "SE_Ratio", "Coverage")], row.names = FALSE)
  }
  
  # Save processed results
  save(results_df, results_by_scenario_m, file = paste0("processed_results_", scenarios[1], "_M", paste0(M_values, collapse=""), "_", n_reps, "rep.RData"))
}

cat("\n============================================================\n")
cat("Results saved to files:\n")
cat("- raw_results_", scenarios[1], "_M", M_values, "_", n_reps, "rep.RData\n", sep = "")
cat("- processed_results_", scenarios[1], "_M", M_values, "_", n_reps, "rep.RData\n", sep = "")
cat("============================================================\n")
