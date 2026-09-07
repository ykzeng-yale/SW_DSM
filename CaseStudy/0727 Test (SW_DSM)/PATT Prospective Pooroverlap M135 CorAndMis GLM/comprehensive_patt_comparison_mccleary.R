#!/usr/bin/env Rscript
# Comprehensive Comparison: Baseline vs Survey-Weighted Matching Methods for PATT (Poor Overlap)
# McCleary HPC Version - Optimized for FORK cluster with 30 cores
# Multi-M Version: Compares M=1, M=3, and M=5 neighbors
# Model Specification Scenarios: CorCor, MisCor, CorMis, MisMis
# All methods estimate Average Treatment Effect on the Treated (ATT/PATT)
# Comparing:
# 1. Unweighted DSM (dsmatch-master with bootstrap, GLM logit PS + linear outcome)
# 2. Unweighted PG matching (dsmatch-master with bootstrap, linear outcome model) 
# 3. Unweighted PS matching (dsmatch-master with bootstrap, GLM logit PS)
# 4. Survey-weighted PS full matching (MatchIt with marginaleffects, quasibinomial PS)
# 5. Survey-weighted DSM (Version 1 WDSM - Simplified with all updates:
#    quasibinomial PS + weighted LM + polynomial sieve + weighted standardization)
#
# Model Specification Scenarios:
# - CorCor: Both PS and PGS models correct (include X1:X2 interaction)
# - MisCor: PS misspecified (no X1:X2), PGS correct (has X1:X2)
# - CorMis: PS correct (has X1:X2), PGS misspecified (no X1:X2)
# - MisMis: Both PS and PGS misspecified (no X1:X2 in both)

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
library(marginaleffects)
library(parallel)
library(doParallel)
library(foreach)
library(boot)
library(R.utils)  # For withTimeout

# Source required functions
cat("Sourcing custom functions...\n")

# Source ALL necessary dsmatch functions (not using devtools::load_all for HPC)
cat("Sourcing dsmatch functions...\n")
dsmatch_files <- c(
  "dsmatch-master/R/bisect.R",
  "dsmatch-master/R/is.lp.R",
  "dsmatch-master/R/is.ps.R", 
  "dsmatch-master/R/is.pg.R",
  "dsmatch-master/R/estforboot_dsATT.R",
  "dsmatch-master/R/estforboot_psATT.R",
  "dsmatch-master/R/estforboot_pgATT.R",
  "dsmatch-master/R/estforboot_covATT.R",
  "dsmatch-master/R/dsmatchATT.R"
)

for (file in dsmatch_files) {
  source(file)
}

# Source WDSM function (simplified version with all updates)
source("WDSM/R/wdsm_patt_prospective_v1_simplified.R")

# Check if optmatch is available for full matching
if (!requireNamespace("optmatch", quietly = TRUE)) {
  warning("optmatch package not available. Full matching may not work properly.")
}

# ============================================================================
# Function to run a single replicate for a specific M value and model specification
# ============================================================================
run_single_replicate_M <- function(i.rep, data, true_patt, M, B, alpha, model_spec = "CorCor") {
  
  # No time limit - let methods run to completion
  # Poor overlap may require more computation time
  
  tryCatch({
    # Source dsmatch functions inside the worker (for PSOCK compatibility)
    dsmatch_files <- c(
      "dsmatch-master/R/bisect.R",
      "dsmatch-master/R/is.lp.R",
      "dsmatch-master/R/is.ps.R", 
      "dsmatch-master/R/is.pg.R",
      "dsmatch-master/R/estforboot_dsATT.R",
      "dsmatch-master/R/estforboot_psATT.R",
      "dsmatch-master/R/estforboot_pgATT.R",
      "dsmatch-master/R/estforboot_covATT.R",
      "dsmatch-master/R/dsmatchATT.R"
    )
    
    for (file in dsmatch_files) {
      source(file)
    }
    
    # Multi-stage sampling (from original PATT prospective code)
    size1 <- rep(100000, 10)  # Population size per stratum
    size2 <- rep(5, 10)       # Number of clusters per stratum
    size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
               rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
               rep(250/5, 5), rep(150/5, 5))  # Cluster-level sample sizes
    
    # Add required columns for sampling
    data$ones <- 1
    data$id <- seq_len(nrow(data))
    
    s <- mstage(data, stage = list("stratified", "cluster", ""), 
                varnames = list("Strata", "Cluster", "ones"), 
                size = list(size1, size2, size3), 
                method = list("", "srswor", "srswor"))
    
    sample <- getdata(data, s)[[3]]  # Extract the final sample
    
    # Add survey weights
    sample$s.wt <- 1 / sample$Prob
    
    # Store both original and normalized weights
    w_original <- sample$s.wt  # Original unnormalized weights for WDSM
    
    # Normalize survey weights: w × length(w)/sum(w) for PS Full
    # This preserves the effective sample size
    w_normalized <- sample$s.wt * length(sample$s.wt) / sum(sample$s.wt)
    
    # Extract variables
    Y <- sample$y
    X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
    A <- sample$z
    
    # Note: We'll use w_normalized for PS Full and w_original for WDSM
    
    # Store sample size info
    n_sample <- nrow(sample)
    n_treated <- sum(A == 1)
    n_control <- sum(A == 0)
    
    # Initialize results for this replicate
    replicate_results <- list(
      n_sample = n_sample,
      n_treated = n_treated,
      n_control = n_control,
      M = M,  # Add M value to results
      model_spec = model_spec  # Add model specification scenario
    )
    
    # Determine which formulas to use based on model specification
    # PS model: used for propensity score estimation
    # PGS model: used for prognostic score estimation
    ps_correct <- model_spec %in% c("CorCor", "CorMis")  # PS correct if CorCor or CorMis
    pgs_correct <- model_spec %in% c("CorCor", "MisCor")  # PGS correct if CorCor or MisCor
    
    # ============================================================
    # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch-master)
    # ============================================================
    tryCatch({
      # Create covariate matrices based on model specification
      # For PS model
      if (ps_correct) {
        X_ps_dsm <- cbind(X, X[,1] * X[,2])  # Include interaction
        colnames(X_ps_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        X_ps_dsm <- X  # No interaction
        colnames(X_ps_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      # For PGS model
      if (pgs_correct) {
        X_pg_dsm <- cbind(X, X[,1] * X[,2])  # Include interaction
        colnames(X_pg_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        X_pg_dsm <- X  # No interaction
        colnames(X_pg_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      # Run DSM for ATT with bootstrap
      dsm_result <- withTimeout({
        dsmatchATT(  # Note: using ATT version
          Y = Y,
          X = X_ps_dsm,  # Use PS-specific covariates
          A = A,
          method = "dsm",
          model.ps = "logit",    # Standard GLM with logit link
          model.pg = "linpred",  # Use linear predictors for outcome
          lp.pg = X_pg_dsm,      # Use PGS-specific covariates
          cov.balance = FALSE,
          varest = TRUE,
          boots = B,
          mc = FALSE,  # Don't use internal multicore since we're already in parallel
          ncpus = 1,
          M = M  # Pass the number of matches
        )
      }, timeout = 180, onTimeout = "error")  # 3 minute timeout
      
      replicate_results$dsm_unweighted <- list(
        estimate = dsm_result$est.ds,
        se = sqrt(dsm_result$bootvar[1,1]),
        ci_lower = dsm_result$est.ds - qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1]),
        ci_upper = dsm_result$est.ds + qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1])
      )
      
    }, error = function(e) {
      cat("DSM Unweighted Error in replicate", i.rep, ":", e$message, "\n")
      replicate_results$dsm_unweighted <- list(
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
      # Create covariate matrix based on PGS model specification
      if (pgs_correct) {
        X_pg <- cbind(X, X[,1] * X[,2])  # Include interaction
        colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        X_pg <- X  # No interaction
        colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      # Run PG matching for ATT with bootstrap
      pg_result <- withTimeout({
        dsmatchATT(  # Note: using ATT version
          Y = Y,
          X = X_pg,
          A = A,
          method = "pg",
          model.pg = "linpred",  # Use linear predictors
          lp.pg = X_pg,          # Use PGS-specific covariates
          cov.balance = FALSE,
          varest = TRUE,
          boots = B,
          mc = FALSE,
          ncpus = 1,
          M = M  # Pass the number of matches
        )
      }, timeout = 180, onTimeout = "error")  # 3 minute timeout
      
      replicate_results$pg_unweighted <- list(
        estimate = pg_result$est.pg,
        se = sqrt(pg_result$bootvar[1,1]),
        ci_lower = pg_result$est.pg - qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1]),
        ci_upper = pg_result$est.pg + qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1])
      )
      
    }, error = function(e) {
      cat("PG Unweighted Error in replicate", i.rep, ":", e$message, "\n")
      replicate_results$pg_unweighted <- list(
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
      # Create covariate matrix based on PS model specification
      if (ps_correct) {
        X_ps <- cbind(X, X[,1] * X[,2])  # Include interaction
        colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      } else {
        X_ps <- X  # No interaction
        colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6")
      }
      
      # Run PS matching for ATT with bootstrap
      ps_result <- withTimeout({
        dsmatchATT(  # Note: using ATT version
          Y = Y,
          X = X_ps,  # Use PS-specific covariates
          A = A,
          method = "ps",  # Propensity score matching
          model.ps = "logit",    # Standard GLM with logit link
          cov.balance = FALSE,
          varest = TRUE,
          boots = B,
          mc = FALSE,
          ncpus = 1,
          M = M  # Pass the number of matches
        )
      }, timeout = 180, onTimeout = "error")  # 3 minute timeout
      
      replicate_results$ps_unweighted <- list(
        estimate = ps_result$est.ps,
        se = sqrt(ps_result$bootvar[1,1]),
        ci_lower = ps_result$est.ps - qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1]),
        ci_upper = ps_result$est.ps + qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1])
      )
      
    }, error = function(e) {
      cat("PS Unweighted Error in replicate", i.rep, ":", e$message, "\n")
      replicate_results$ps_unweighted <- list(
        estimate = NA,
        se = NA,
        ci_lower = NA,
        ci_upper = NA
      )
    })
    
    # ============================================================
    # METHOD 4: SURVEY-WEIGHTED PROPENSITY SCORE MATCHING (MatchIt)
    # Using FULL MATCHING as recommended in MatchIt vignette for survey weights
    # ============================================================
    tryCatch({
      # Create data frame with normalized survey weights
      # PS Full requires normalized weights: w × length(w)/sum(w) to preserve effective sample size
      match_data_sw <- data.frame(
        Y = Y,
        A = A,
        x1 = X[,1],
        x2 = X[,2],
        x3 = X[,3],
        x4 = X[,4],
        x5 = X[,5],
        x6 = X[,6],
        sw = w_normalized  # Using normalized survey weights for PS Full
      )
      
      # Following MatchIt vignette recommendations for survey-weighted matching
      # Using full matching which handles survey weights well
      # Note: MatchIt automatically uses quasibinomial (not binomial) when survey weights are present
      # Formula depends on PS model specification
      if (ps_correct) {
        ps_formula <- A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2
      } else {
        ps_formula <- A ~ x1 + x2 + x3 + x4 + x5 + x6
      }
      
      m_ps_sw <- matchit(
        ps_formula,
        data = match_data_sw,
        method = "full",         # Full matching (recommended for survey weights)
        distance = "glm",        # Default GLM for PS estimation (quasibinomial with weights)
        link = "logit",
        s.weights = ~ sw,        # Include survey weights in PS estimation
        estimand = "ATT"         # ATT estimation
      )
      
      # Extract matched data with combined weights
      # By default, weights = matching weights × survey weights
      # Use match.data for HPC compatibility (not match_data)
      md_sw <- match.data(m_ps_sw)
      
      # Follow MatchIt vignette recommendations for ATT with survey weights:
      # Step 1: Fit outcome model with combined weights
      fit_sw <- lm(Y ~ A * (x1 + x2 + x3 + x4 + x5 + x6 + x1:x2), 
                   data = md_sw,
                   weights = weights)  # Combined matching * survey weights
      
      # Step 2: Use marginaleffects to compute marginal ATT
      # For ATT with prospective sampling (PATT):
      # - newdata = subset where A == 1 (average over treated units)
      # - wts = "sw" (use only survey weights for marginalization)
      # - vcov = ~subclass (cluster by full matching subclasses)
      att_result <- avg_comparisons(
        fit_sw,
        variables = "A",
        vcov = ~subclass,       # Cluster-robust SEs for full matching
        newdata = subset(md_sw, A == 1),  # ATT: average over treated units
        wts = "sw"              # Only survey weights for marginalization
      )
      
      # Extract results
      replicate_results$ps_weighted <- list(
        estimate = att_result$estimate[1],
        se = att_result$std.error[1],
        ci_lower = att_result$conf.low[1],
        ci_upper = att_result$conf.high[1]
      )
      
    }, error = function(e) {
      cat("PS Survey-Weighted Error in replicate", i.rep, ":", e$message, "\n")
      replicate_results$ps_weighted <- list(
        estimate = NA,
        se = NA,
        ci_lower = NA,
        ci_upper = NA
      )
    })
    
    # ============================================================
    # METHOD 5: SURVEY-WEIGHTED DOUBLE SCORE MATCHING (Version 1 WDSM)
    # ============================================================
    tryCatch({
      # WDSM v1_simplified now accepts formula parameters for flexible model specification
      # Prepare X with interaction term (it will be used based on formulas)
      X_wdsm <- cbind(X, X[,1] * X[,2])
      colnames(X_wdsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      
      # Create formulas based on model specification
      if (ps_correct) {
        ps_formula_wdsm <- "A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2"
      } else {
        ps_formula_wdsm <- "A ~ x1 + x2 + x3 + x4 + x5 + x6"
      }
      
      if (pgs_correct) {
        pgs_formula_wdsm <- "Y ~ x1 + x2 + x3 + x4 + x5 + x6 + x1_x2"
      } else {
        pgs_formula_wdsm <- "Y ~ x1 + x2 + x3 + x4 + x5 + x6"
      }
      
      # Create data structure for WDSM with ORIGINAL unnormalized survey weights
      sample_wdsm <- list(
        X = X_wdsm,  # X matrix with all columns including interaction
        A = A,
        Y = Y,
        w = w_original  # Using ORIGINAL unnormalized survey weights for WDSM
      )
      
      # Use the simplified WDSM function with formula parameters
      wdsm_result <- withTimeout({
        wdsm_patt_prospective_v1_simplified(
          sample = sample_wdsm,
          M = M,
          B = B,
          ps_formula = ps_formula_wdsm,   # Pass PS formula
          pgs_formula = pgs_formula_wdsm,  # Pass PGS formula
          show_progress = FALSE  # Turn off progress in parallel
        )
      }, timeout = 240, onTimeout = "error")  # 4 minute timeout
      
      replicate_results$dsm_weighted <- list(
        estimate = wdsm_result$tau_hat,
        se = wdsm_result$SE,
        ci_lower = wdsm_result$CI_lower,
        ci_upper = wdsm_result$CI_upper
      )
      
    }, error = function(e) {
      cat("WDSM Error in replicate", i.rep, ":", e$message, "\n")
      replicate_results$dsm_weighted <- list(
        estimate = NA,
        se = NA,
        ci_lower = NA,
        ci_upper = NA
      )
    })
    
    return(replicate_results)
    
  }, error = function(e) {
    cat("Replicate", i.rep, "M=", M, "failed:", e$message, "\n")
    return(list(error = paste("Replicate", i.rep, "M=", M, "failed:", e$message)))
  })
}

# ============================================================================
# Wrapper function to run all M values and model specifications for a single replicate
# ============================================================================
run_single_replicate <- function(i.rep, data, true_patt, M_values, B, alpha) {
  results <- list()
  
  # Define model specification scenarios
  model_specs <- c("CorCor", "MisCor", "CorMis", "MisMis")
  
  for (model_spec in model_specs) {
    results_by_M <- list()
    
    for (M in M_values) {
      if (i.rep %% 20 == 0) {
        cat("  Running M =", M, ", Model Spec =", model_spec, "\n")
      }
      
      results_by_M[[paste0("M", M)]] <- run_single_replicate_M(i.rep, data, true_patt, M, B, alpha, model_spec)
    }
    
    results[[model_spec]] <- results_by_M
  }
  
  return(results)
}

# ============================================================================
# Main Simulation
# ============================================================================

# Set parameters
M_values <- c(1, 3, 5)  # Different numbers of matches to compare
B <- 200          # Bootstrap iterations
alpha <- 0.05     # Significance level
n_reps <- 1000    # Number of replicates (full run)

# Record start time
start_time <- Sys.time()

cat("\n============================================================\n")
cat("COMPREHENSIVE PATT COMPARISON - SIMULATION PARAMETERS:\n")
cat("============================================================\n")
cat("Number of replicates:", n_reps, "\n")
cat("Number of matches (M) to compare:", paste(M_values, collapse=", "), "\n")
cat("Bootstrap iterations:", B, "\n")
cat("Significance level:", alpha, "\n")

# ============================================================================
# Load Population Data
# ============================================================================
cat("\n============================================================\n")
cat("Loading population data...\n")
cat("============================================================\n")

load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_PoorOverlap_AllinOne_0118_2025

# Access scenario 1 data (poor overlap)
data <- data_sets[[1]]

# Calculate true population PATT
true_patt <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])
cat("True Population PATT:", round(true_patt, 4), "\n")

# ============================================================================
# Setup Parallel Processing - FORK for better stability
# ============================================================================
n_cores <- 30  # Use 30 cores for faster processing
cat("\n============================================================\n")
cat("Setting up parallel backend with", n_cores, "cores (FORK cluster)...\n")
cat("============================================================\n")

cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

# Run simulation with larger batch size
batch_size <- 100  # Process in batches
n_batches <- ceiling(n_reps / batch_size)

cat("\n============================================================\n")
cat("Running simulation in", n_batches, "batches of", batch_size, "replicates each...\n")
cat("============================================================\n")

all_results <- foreach(i = 1:n_reps,
                      .combine = 'c',
                      .multicombine = TRUE,
                      .maxcombine = batch_size,
                      .inorder = FALSE,
                      .errorhandling = 'pass',
                      .packages = c('survey', 'sampling', 'MASS', 'nnet', 
                                   'MatchIt', 'marginaleffects', 'boot', 'R.utils', 'glmnet'),
                      .export = c('run_single_replicate', 'run_single_replicate_M', 'wdsm_patt_prospective_v1_simplified',
                                 'data', 'true_patt', 'M_values', 'B', 'alpha',
                                 'dsmatchATT', 'match.data', 'avg_comparisons')) %dopar% {
  
  # Progress tracking
  if (i %% 20 == 0) {
    cat("Starting replicate", i, "of", n_reps, "\n")
  }
  
  set.seed(20250115 + i)
  
  # Run with memory management
  gc()  # Garbage collection before starting
  
  result <- run_single_replicate(i, data, true_patt, M_values, B, alpha)
  
  gc()  # Garbage collection after completion
  
  list(result)  # Wrap in list for combine
}

# Clean up parallel cluster
stopCluster(cl)

end_time <- Sys.time()
cat("\nTotal runtime:", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")

# ============================================================================
# Analyze Results
# ============================================================================
cat("\n\n============================================================\n")
cat("FINAL RESULTS SUMMARY - PATT COMPARISON WITH MODEL SPECIFICATIONS\n")
cat("============================================================\n")

# Extract results for analysis
methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", "dsm_weighted")
method_names <- c("DSM (Unweighted)", "PG (Unweighted)", "PS (Unweighted)", 
                  "PS Full (Survey-Weighted)", "WDSM V1 (Survey-Weighted)")

# Model specification names
model_specs <- c("CorCor", "MisCor", "CorMis", "MisMis")
model_spec_names <- c("Both Correct", "PS Mis/PGS Cor", "PS Cor/PGS Mis", "Both Misspecified")

# Initialize summary statistics for all combinations
summary_stats_all <- list()

# Calculate summary statistics for each model specification and M value
for (model_spec in model_specs) {
  cat("\n\n============================================================\n")
  cat("MODEL SPECIFICATION:", model_spec_names[which(model_specs == model_spec)], "\n")
  cat("============================================================\n")
  
  for (M in M_values) {
    M_key <- paste0("M", M)
    spec_M_key <- paste0(model_spec, "_M", M)
    
    cat("\n========== Results for M =", M, "=========\n")
    
    # Initialize summary statistics for this combination
    summary_stats <- data.frame(
      Method = method_names,
      Model_Spec = model_spec,
      M = M,
      Mean_Estimate = numeric(length(methods)),
      Mean_SE = numeric(length(methods)),
      Bias = numeric(length(methods)),
      Relative_Bias = numeric(length(methods)),
      RMSE = numeric(length(methods)),
      Coverage = numeric(length(methods)),
      Mean_CI_Width = numeric(length(methods)),
      N_Failed = numeric(length(methods))
    )
    
    for (i in seq_along(methods)) {
      method <- methods[i]
      
      # Extract estimates, SEs, and CIs across all replicates for this model spec and M
      estimates <- unlist(sapply(all_results, function(x) {
        if (!is.null(x[[1]][[model_spec]][[M_key]][[method]]$estimate)) {
          x[[1]][[model_spec]][[M_key]][[method]]$estimate
        } else NA
      }))
      ses <- unlist(sapply(all_results, function(x) {
        if (!is.null(x[[1]][[model_spec]][[M_key]][[method]]$se)) {
          x[[1]][[model_spec]][[M_key]][[method]]$se
        } else NA
      }))
      ci_lowers <- unlist(sapply(all_results, function(x) {
        if (!is.null(x[[1]][[model_spec]][[M_key]][[method]]$ci_lower)) {
          x[[1]][[model_spec]][[M_key]][[method]]$ci_lower
        } else NA
      }))
      ci_uppers <- unlist(sapply(all_results, function(x) {
        if (!is.null(x[[1]][[model_spec]][[M_key]][[method]]$ci_upper)) {
          x[[1]][[model_spec]][[M_key]][[method]]$ci_upper
        } else NA
      }))
  
      # Count failures
      n_failed <- sum(is.na(estimates))
      summary_stats$N_Failed[i] <- n_failed
      
      # Remove NAs
      valid <- !is.na(estimates)
      estimates <- estimates[valid]
      ses <- ses[valid]
      ci_lowers <- ci_lowers[valid]
      ci_uppers <- ci_uppers[valid]
      
      if (length(estimates) > 0) {
        # Mean estimate and SE
        summary_stats$Mean_Estimate[i] <- mean(estimates)
        summary_stats$Mean_SE[i] <- mean(ses)
        
        # Bias
        summary_stats$Bias[i] <- mean(estimates) - true_patt
        
        # Relative bias (relative to true PATT)
        summary_stats$Relative_Bias[i] <- (mean(estimates) - true_patt) / true_patt
        
        # RMSE
        summary_stats$RMSE[i] <- sqrt(mean((estimates - true_patt)^2))
        
        # Coverage
        coverage <- mean(ci_lowers <= true_patt & ci_uppers >= true_patt)
        summary_stats$Coverage[i] <- coverage
        
        # Mean CI width
        summary_stats$Mean_CI_Width[i] <- mean(ci_uppers - ci_lowers)
      }
    }
    
    # Print summary table for this combination
    cat("\nSummary Statistics for M =", M, ", Model Spec =", model_spec, ":\n")
    cat("True PATT:", round(true_patt, 4), "\n")
    print(summary_stats[, c("Method", "Mean_Estimate", "Mean_SE", "Bias", 
                           "Relative_Bias", "RMSE", "Coverage", "N_Failed")], 
          digits = 4)
    
    # Store results with combined key
    summary_stats_all[[spec_M_key]] <- summary_stats
  }
}

# ============================================================================
# Calculate Empirical Variance and Relative Efficiency for Each Combination
# ============================================================================
cat("\n\n============================================================\n")
cat("EMPIRICAL VARIANCE AND RELATIVE EFFICIENCY BY MODEL SPECIFICATION\n")
cat("============================================================\n")

for (model_spec in model_specs) {
  cat("\n\n============================================================\n")
  cat("MODEL SPECIFICATION:", model_spec_names[which(model_specs == model_spec)], "\n")
  cat("============================================================\n")
  
  for (M in M_values) {
    M_key <- paste0("M", M)
    spec_M_key <- paste0(model_spec, "_M", M)
    
    cat("\n========== M =", M, "=========\n")
    
    # Build matrix of estimates for empirical variance calculation
    est_list <- lapply(methods, function(m) {
      sapply(all_results, function(res) {
        if (!is.null(res[[1]][[model_spec]][[M_key]][[m]]) && 
            !is.null(res[[1]][[model_spec]][[M_key]][[m]]$estimate)) {
          as.numeric(res[[1]][[model_spec]][[M_key]][[m]]$estimate)
        } else {
          NA
        }
      })
    })
    est_mat <- do.call(cbind, est_list)
    colnames(est_mat) <- methods

    # Ensure est_mat is a matrix
    if (!is.matrix(est_mat)) {
      est_mat <- as.matrix(est_mat)
    }
    
    # Remove rows with any NAs so every method is judged on same replicates
    good_rows <- rowSums(is.na(est_mat)) == 0
    est_mat_clean <- est_mat[good_rows, , drop = FALSE]
    
    # Calculate empirical (Monte Carlo) variances
    if (nrow(est_mat_clean) > 1) {
      empirical_var <- apply(est_mat_clean, 2, var)
    } else {
      # Not enough valid rows to calculate variance
      empirical_var <- rep(NA, ncol(est_mat_clean))
    }
    names(empirical_var) <- method_names
    
    # Calculate relative efficiency using empirical variance (PS unweighted as reference)
    # Reference is PS (Unweighted) which is the 3rd method
    ref_idx <- 3
    relative_efficiency <- empirical_var[ref_idx] / empirical_var

    # Add empirical SD and relative efficiency to summary
    if (!is.null(summary_stats_all[[spec_M_key]])) {
      summary_stats_all[[spec_M_key]]$Empirical_SD <- sqrt(empirical_var)
      summary_stats_all[[spec_M_key]]$Relative_Efficiency <- relative_efficiency
    }
    
    # Print variance-based efficiency analysis
    cat("\nVariance-Based Relative Efficiency Analysis (M =", M, ", Model Spec =", model_spec, "):\n")
    cat("Reference method: PS (Unweighted)\n")
    cat("Number of valid replicates used:", nrow(est_mat_clean), "\n\n")
    
    efficiency_table <- data.frame(
      Method = method_names,
      Mean_SE = if (!is.null(summary_stats_all[[spec_M_key]])) summary_stats_all[[spec_M_key]]$Mean_SE else NA,
      Empirical_SD = sqrt(empirical_var),
      Relative_Efficiency = relative_efficiency
    )
    print(efficiency_table, digits = 4)
    
    cat("\nInterpretation: RE > 1 means more efficient than PS (Unweighted)\n")
    cat("e.g., RE = 1.25 means 25% reduction in sampling variance\n")
  }
}

# Save results
model_specs_used <- c("CorCor", "MisCor", "CorMis", "MisMis")
save(all_results, summary_stats_all, true_patt, M_values, model_specs_used,
     file = "comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap_results.RData")
cat("\n\nResults saved to 'comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap_results.RData'\n")
cat("Results structure: all_results[[replicate]][[model_spec]][[M]][[method]]\n")
cat("Model specifications included: CorCor, MisCor, CorMis, MisMis\n")

# ============================================================================
# Create visualization for all M values
# ============================================================================
library(ggplot2)
library(tidyr)
library(dplyr)

# Combine all summary stats into one data frame
all_plot_data <- bind_rows(
  lapply(names(summary_stats_all), function(M_key) {
    summary_stats_all[[M_key]] %>%
      mutate(M_label = paste0("M=", gsub("M", "", M_key)))
  })
)

# Prepare data for plotting
plot_data <- all_plot_data %>%
  select(Method, M_label, Relative_Bias, Relative_Efficiency, Coverage) %>%
  pivot_longer(cols = c(Relative_Bias, Relative_Efficiency, Coverage),
               names_to = "Metric",
               values_to = "Value")

# Create comparison plot faceted by M
p <- ggplot(plot_data, aes(x = Method, y = Value, fill = Method)) +
  geom_bar(stat = "identity") +
  facet_grid(M_label ~ Metric, scales = "free_y") +
  theme_minimal(base_size = 10) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none",
    strip.text = element_text(face = "bold", size = 10)
  ) +
  labs(
    title = "Comparison of Matching Methods for PATT (Poor Overlap): Baseline vs Survey-Weighted",
    subtitle = sprintf("True PATT = %.4f | N replicates = %d | M = 1,3,5 | B = %d", 
                       true_patt, n_reps, B),
    y = "Value",
    x = ""
  ) +
  scale_fill_brewer(palette = "Set3")
  
# Add reference lines
p <- p + 
  geom_hline(data = filter(plot_data, Metric == "Coverage"),
             aes(yintercept = 0.95), linetype = "dashed", color = "red") +
  geom_hline(data = filter(plot_data, Metric == "Relative_Bias"),
             aes(yintercept = 0), linetype = "dashed", color = "red") +
  geom_hline(data = filter(plot_data, Metric == "Relative_Efficiency"),
             aes(yintercept = 1), linetype = "dashed", color = "red")

# Save plot
ggsave("comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap_plot.pdf", p, width = 14, height = 10)
cat("\nPlot saved to 'comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap_plot.pdf'\n")
  
# Create boxplot for estimates across all M values
boxplot_data <- data.frame()
for (M in M_values) {
  M_key <- paste0("M", M)
  for (i in seq_along(methods)) {
    method <- methods[i]
    estimates <- unlist(sapply(all_results, function(x) {
      if (!is.null(x[[1]][[M_key]][[method]]$estimate)) x[[1]][[M_key]][[method]]$estimate else NA
    }))
    valid <- !is.na(estimates)
    estimates <- estimates[valid]
    
    if (length(estimates) > 0) {
      temp_df <- data.frame(
        Method = method_names[i],
        M_label = paste0("M=", M),
        Estimate = estimates
      )
      boxplot_data <- rbind(boxplot_data, temp_df)
    }
  }
}

# Create boxplot faceted by M
if (nrow(boxplot_data) > 0) {
  p_box <- ggplot(boxplot_data, aes(x = Method, y = Estimate, fill = Method)) +
    geom_boxplot(alpha = 0.7) +
    geom_hline(yintercept = true_patt, color = "red", linetype = "dashed", linewidth = 1) +
    facet_wrap(~M_label, ncol = 3) +
    theme_minimal(base_size = 10) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
      legend.position = "none"
    ) +
    labs(
      title = "Distribution of PATT Estimates Across Methods and M Values (Poor Overlap)",
      subtitle = sprintf("True PATT = %.4f (red dashed line)", true_patt),
      y = "PATT Estimate",
      x = "Method"
    ) +
    scale_fill_brewer(palette = "Set3")
  
  # Save boxplot
  ggsave("comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap_boxplot.pdf", p_box, width = 12, height = 6)
  cat("\nBoxplot saved to 'comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap_boxplot.pdf'\n")
} else {
  cat("\nSkipping visualization due to insufficient valid results.\n")
}

# ============================================================================
# Create detailed results tables for each M
# ============================================================================
cat("\n\n============================================================\n")
cat("DETAILED RESULTS TABLES\n")
cat("============================================================\n")

for (M in M_values) {
  M_key <- paste0("M", M)
  
  cat("\n========== M =", M, "=========\n")
  
  summary_stats <- summary_stats_all[[M_key]]
  
  detailed_results <- data.frame(
    Method = summary_stats$Method,
    Estimate = sprintf("%.4f", summary_stats$Mean_Estimate),
    SE = sprintf("%.4f", summary_stats$Mean_SE),
    Emp_SD = sprintf("%.4f", summary_stats$Empirical_SD),
    Bias = sprintf("%.4f", summary_stats$Bias),
    Bias_Percent = sprintf("%.1f%%", summary_stats$Relative_Bias * 100),
  RMSE = sprintf("%.4f", summary_stats$RMSE),
  Coverage = sprintf("%.1f%%", summary_stats$Coverage * 100),
  Rel_Eff = sprintf("%.2f", summary_stats$Relative_Efficiency),
  CI_Width = sprintf("%.4f", summary_stats$Mean_CI_Width),
  Failed = sprintf("%d/%d", summary_stats$N_Failed, n_reps)
  )
  
  cat("\nDetailed Results Table (M =", M, "):\n")
  print(detailed_results, row.names = FALSE)
  
  # Save detailed results for this M
  write.csv(detailed_results, 
            sprintf("comprehensive_patt_comparison_M%d_Pooroverlap_table.csv", M), 
            row.names = FALSE)
  cat(sprintf("\nDetailed results table saved to 'comprehensive_patt_comparison_M%d_Pooroverlap_table.csv'\n", M))
}



# Report computation time
cat("\nTotal computation time:", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")
cat("Average time per replicate:", round(difftime(end_time, start_time, units = "secs") / n_reps, 2), "seconds\n")
cat("Note: Each replicate included", length(M_values), "different M values\n")

cat("\n============================================================\n")
cat("PATT COMPARISON ANALYSIS COMPLETED (M=1,3,5)\n")
cat("============================================================\n")