##############################################################################
# PATE Estimation with Retrospective Sampling - Model Misspecification Analysis
# Uses correct variable names from original data structure
##############################################################################

# Load required packages
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
library(R.utils)
library(dplyr)
library(tidyr)
library(purrr)
library(matrixStats)
library(Hmisc)

# Source external functions
source("../dsmatch-master/R/dsmatchATE.R")
source("../wdsm_method2_multinomial_bootstrap.R")
source("../wdsm_ci_functions.R")

# Load population data - uses original variable names
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")

# Extract the dataset (scenario 1)
population <- SuperPopGen_GoodOverlap_AllinOne_0118_2025[[1]]

# Set parameters
N <- nrow(population)  # Population size
n <- 5000  # Sample size for retrospective sampling

# Define the scenario from environment variable or default
scenario <- Sys.getenv("SCENARIO", "CorCor")

# Set model specification based on scenario
use_interaction_ps <- scenario %in% c("CorCor", "CorMis")
use_interaction_pg <- scenario %in% c("CorCor", "MisCor")

cat("\n=====================================\n")
cat("Running scenario:", scenario, "\n")
cat("PS model includes interaction:", use_interaction_ps, "\n")
cat("PG model includes interaction:", use_interaction_pg, "\n")
cat("=====================================\n\n")

# Helper functions
expit <- function(x) exp(x) / (1 + exp(x))
qlogis <- function(p) log(p / (1 - p))

# True PATE in the population
true_pate <- mean(population$y1) - mean(population$y0)
cat("True PATE in population:", true_pate, "\n\n")

##############################################################################
# RETROSPECTIVE SAMPLING FUNCTION
##############################################################################
perform_retrospective_sampling <- function(population, n) {
  N <- nrow(population)
  
  # Retrospective sampling model coefficients (from original setup)
  c0 <- log(n/N / (1 - n/N))  # Adjusted for desired sample size
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)  # Treatment effect on sampling
  
  # Calculate sampling probabilities
  formula_S <- c0 + delta_z_in_s * population$z + c1 * population$x1 + 
    c2 * population$x2 + c3 * population$x3 + c4 * population$x4 + 
    c5 * population$x5 + c6 * population$x6
  
  prob_S <- expit(formula_S)
  
  # Sample based on these probabilities
  population$Prob <- prob_S
  population$S <- rbinom(N, 1, prob_S)
  
  # Extract sample
  sample <- population[population$S == 1, ]
  
  # Add survey weights
  sample$s.wt <- 1 / sample$Prob
  
  # Normalize weights for stability
  sample$sw <- sample$s.wt * nrow(sample) / sum(sample$s.wt)
  
  return(sample)
}

##############################################################################
# SINGLE REPLICATE FUNCTION
##############################################################################
run_single_replicate <- function(rep_id, population, M = 1, use_interaction_ps, use_interaction_pg) {
  set.seed(123456 + rep_id)
  
  tryCatch({
    # Perform retrospective sampling
    sample <- perform_retrospective_sampling(population, n)
    n_sample <- nrow(sample)
    
    # Prepare data matrices
    # PS model covariates
    if (use_interaction_ps) {
      X_ps <- model.matrix(~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2 - 1, data = sample)
    } else {
      X_ps <- model.matrix(~ x1 + x2 + x3 + x4 + x5 + x6 - 1, data = sample)
    }
    
    # PG model covariates
    if (use_interaction_pg) {
      X_pg <- model.matrix(~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2 - 1, data = sample)
    } else {
      X_pg <- model.matrix(~ x1 + x2 + x3 + x4 + x5 + x6 - 1, data = sample)
    }
    
    # Covariate matrix for matching (always includes interaction for matching distance)
    X_match <- model.matrix(~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2 - 1, data = sample)
    
    results <- list()
    
    ##########################################################################
    # 1. UNWEIGHTED DOUBLE SCORE MATCHING (DSM)
    ##########################################################################
    dsm_result <- tryCatch({
      dsm_fit <- dsmatchATE(
        Y = sample$y,
        Tr = sample$z,
        X = X_ps,  # PS model covariates
        lp.pg = X_pg,  # PG model covariates (separate specification)
        M = M,
        estimand = "PATE",
        model.ps = "logit",  # Always logit for PS
        model.pg = "linpred",  # Linear predictor for PG when lp.pg provided
        weights = rep(1, n_sample),
        return.se = TRUE
      )
      
      list(
        estimate = dsm_fit$ATE.est,
        se = dsm_fit$ATE.se,
        ci_lower = dsm_fit$ATE.est - 1.96 * dsm_fit$ATE.se,
        ci_upper = dsm_fit$ATE.est + 1.96 * dsm_fit$ATE.se
      )
    }, error = function(e) {
      list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, error = as.character(e))
    })
    results$DSM_Unweighted <- dsm_result
    
    ##########################################################################
    # 2. UNWEIGHTED PROGNOSTIC SCORE MATCHING (PG)
    ##########################################################################
    pg_result <- tryCatch({
      pg_fit <- dsmatchATE(
        Y = sample$y,
        Tr = sample$z,
        X = X_match,  # Full covariate matrix (always with interaction)
        M = M,
        estimand = "PATE",
        model.ps = "none",
        model.pg = if (use_interaction_pg) "glm" else "glm",  # Always GLM
        weights = rep(1, n_sample),
        return.se = TRUE
      )
      
      list(
        estimate = pg_fit$ATE.est,
        se = pg_fit$ATE.se,
        ci_lower = pg_fit$ATE.est - 1.96 * pg_fit$ATE.se,
        ci_upper = pg_fit$ATE.est + 1.96 * pg_fit$ATE.se
      )
    }, error = function(e) {
      list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, error = as.character(e))
    })
    results$PG_Unweighted <- pg_result
    
    ##########################################################################
    # 3. UNWEIGHTED PROPENSITY SCORE MATCHING (PS)
    ##########################################################################
    ps_result <- tryCatch({
      ps_fit <- dsmatchATE(
        Y = sample$y,
        Tr = sample$z,
        X = X_ps,  # PS model covariates
        M = M,
        estimand = "PATE",
        model.ps = "logit",  # Always logit
        model.pg = "none",
        weights = rep(1, n_sample),
        return.se = TRUE
      )
      
      list(
        estimate = ps_fit$ATE.est,
        se = ps_fit$ATE.se,
        ci_lower = ps_fit$ATE.est - 1.96 * ps_fit$ATE.se,
        ci_upper = ps_fit$ATE.est + 1.96 * ps_fit$ATE.se
      )
    }, error = function(e) {
      list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, error = as.character(e))
    })
    results$PS_Unweighted <- ps_result
    
    ##########################################################################
    # 4. SURVEY-WEIGHTED PROPENSITY SCORE FULL MATCHING (MatchIt)
    ##########################################################################
    sw_ps_result <- tryCatch({
      # PS model formula
      if (use_interaction_ps) {
        ps_formula <- z ~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2
      } else {
        ps_formula <- z ~ x1 + x2 + x3 + x4 + x5 + x6
      }
      
      # Full matching with survey weights
      m_out <- matchit(
        formula = ps_formula,
        data = sample,
        method = "full",
        estimand = "ATE",
        s.weights = sample$sw  # Normalized survey weights
      )
      
      # Outcome model - ALWAYS fully specified for bias correction
      outcome_formula <- y ~ z * (x1 + x2 + x3 + x4 + x5 + x6 + x1:x2)
      
      # Fit outcome model
      fit <- lm(outcome_formula, data = sample, weights = m_out$weights * sample$sw)
      
      # Get ATE using marginaleffects
      ate_result <- avg_comparisons(
        fit,
        variables = "z",
        vcov = ~subclass,
        wts = "sw",
        newdata = sample
      )
      
      list(
        estimate = ate_result$estimate,
        se = ate_result$std.error,
        ci_lower = ate_result$conf.low,
        ci_upper = ate_result$conf.high
      )
    }, error = function(e) {
      list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, error = as.character(e))
    })
    results$SW_PS_Full <- sw_ps_result
    
    ##########################################################################
    # 5. WEIGHTED DOUBLE SCORE MATCHING (WDSM) with Multinomial Bootstrap
    ##########################################################################
    wdsm_result <- tryCatch({
      wdsm_fit <- method2_multinomial_bootstrap_ci(
        sample_data = sample,
        population_data = NULL,
        outcome_col = "y",
        treatment_col = "z",
        covariate_cols = c("x1", "x2", "x3", "x4", "x5", "x6"),
        weight_col = "s.wt",
        M = M,
        estimand = "PATE",
        design = "retrospective",
        boot_reps = 200,
        use_interaction_ps = use_interaction_ps,
        use_interaction_pg = use_interaction_pg
      )
      
      list(
        estimate = wdsm_fit$estimate,
        se = wdsm_fit$se,
        ci_lower = wdsm_fit$ci_lower,
        ci_upper = wdsm_fit$ci_upper
      )
    }, error = function(e) {
      list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA, error = as.character(e))
    })
    results$WDSM <- wdsm_result
    
    return(results)
    
  }, error = function(e) {
    cat("Error in replicate", rep_id, ":", as.character(e), "\n")
    return(NULL)
  })
}

##############################################################################
# MAIN SIMULATION
##############################################################################

# Simulation parameters
n_reps <- 1000
n_cores <- 30  # Matching SLURM allocation
batch_size <- 50  # Smaller batches for better load balancing
M_values <- c(1, 3, 5)  # Run all M values

# Initialize storage
all_results <- list()

for (M in M_values) {
  cat("\n=====================================\n")
  cat("Running simulations for M =", M, "\n")
  cat("=====================================\n\n")
  
  # Set up parallel processing
  cl <- makeCluster(n_cores, type = "FORK", outfile = "")
  registerDoParallel(cl)
  
  # Run simulations in parallel with batching
  results_M <- foreach(
    batch_start = seq(1, n_reps, by = batch_size),
    .combine = 'c',
    .errorhandling = 'pass',
    .maxcombine = batch_size
  ) %dopar% {
    batch_end <- min(batch_start + batch_size - 1, n_reps)
    batch_results <- vector("list", batch_end - batch_start + 1)
    
    for (i in seq_along(batch_results)) {
      rep_id <- batch_start + i - 1
      if (rep_id %% 10 == 0) {
        cat("Processing replicate", rep_id, "of", n_reps, "\n")
      }
      batch_results[[i]] <- run_single_replicate(
        rep_id, 
        population, 
        M, 
        use_interaction_ps, 
        use_interaction_pg
      )
    }
    
    batch_results
  }
  
  # Stop cluster
  stopCluster(cl)
  
  # Store results
  all_results[[paste0("M", M)]] <- results_M
  
  # Save raw results immediately
  save(all_results, file = paste0("raw_results_", scenario, "_M", M, ".RData"))
  
  cat("Completed simulations for M =", M, "\n")
}

##############################################################################
# PROCESS RESULTS
##############################################################################

# Initialize summary tables
summary_tables <- list()

for (M in M_values) {
  M_key <- paste0("M", M)
  results_M <- all_results[[M_key]]
  
  # Remove NULL results
  results_M <- results_M[!sapply(results_M, is.null)]
  n_valid <- length(results_M)
  
  cat("\nProcessing results for M =", M, "\n")
  cat("Valid replicates:", n_valid, "out of", n_reps, "\n")
  
  # Extract results by method using lapply and unlist for safety
  method_results <- list()
  methods <- c("DSM_Unweighted", "PG_Unweighted", "PS_Unweighted", "SW_PS_Full", "WDSM")
  
  for (method in methods) {
    estimates <- unlist(lapply(results_M, function(r) {
      if (!is.null(r[[method]]$estimate)) r[[method]]$estimate else NA
    }))
    ses <- unlist(lapply(results_M, function(r) {
      if (!is.null(r[[method]]$se)) r[[method]]$se else NA
    }))
    ci_lowers <- unlist(lapply(results_M, function(r) {
      if (!is.null(r[[method]]$ci_lower)) r[[method]]$ci_lower else NA
    }))
    ci_uppers <- unlist(lapply(results_M, function(r) {
      if (!is.null(r[[method]]$ci_upper)) r[[method]]$ci_upper else NA
    }))
    
    # Remove NA values
    valid_idx <- !is.na(estimates) & !is.na(ses)
    estimates <- estimates[valid_idx]
    ses <- ses[valid_idx]
    ci_lowers <- ci_lowers[valid_idx]
    ci_uppers <- ci_uppers[valid_idx]
    
    method_results[[method]] <- list(
      estimates = estimates,
      ses = ses,
      ci_lowers = ci_lowers,
      ci_uppers = ci_uppers
    )
  }
  
  # Calculate summary statistics
  summary_stats <- data.frame(
    Method = methods,
    Scenario = scenario,
    M = M,
    N_Valid = sapply(method_results, function(x) length(x$estimates)),
    Mean_Estimate = sapply(method_results, function(x) mean(x$estimates, na.rm = TRUE)),
    Bias = sapply(method_results, function(x) mean(x$estimates, na.rm = TRUE) - true_pate),
    Relative_Bias = sapply(method_results, function(x) 
      (mean(x$estimates, na.rm = TRUE) - true_pate) / abs(true_pate)),
    Empirical_SD = sapply(method_results, function(x) sd(x$estimates, na.rm = TRUE)),
    Mean_SE = sapply(method_results, function(x) mean(x$ses, na.rm = TRUE)),
    Relative_Efficiency = NA,  # Will be computed below
    Coverage = sapply(method_results, function(x) 
      mean(x$ci_lowers <= true_pate & true_pate <= x$ci_uppers, na.rm = TRUE)),
    RMSE = sapply(method_results, function(x) 
      sqrt(mean((x$estimates - true_pate)^2, na.rm = TRUE))),
    stringsAsFactors = FALSE
  )
  
  # Calculate relative efficiency (SE ratio) using PS_Unweighted as reference
  ps_empirical_sd <- summary_stats$Empirical_SD[summary_stats$Method == "PS_Unweighted"]
  if (length(ps_empirical_sd) > 0 && !is.na(ps_empirical_sd)) {
    summary_stats$Relative_Efficiency <- summary_stats$Mean_SE / summary_stats$Empirical_SD
  }
  
  # Round numeric columns
  numeric_cols <- c("Mean_Estimate", "Bias", "Relative_Bias", "Empirical_SD", 
                   "Mean_SE", "Relative_Efficiency", "Coverage", "RMSE")
  summary_stats[numeric_cols] <- round(summary_stats[numeric_cols], 4)
  
  # Store summary
  summary_tables[[M_key]] <- summary_stats
  
  # Print summary
  cat("\nSummary for M =", M, ":\n")
  print(summary_stats[, c("Method", "Mean_Estimate", "Relative_Bias", 
                          "Relative_Efficiency", "Coverage")])
}

# Save processed results
save(summary_tables, file = paste0("processed_results_", scenario, ".RData"))

# Print final summary
cat("\n=====================================\n")
cat("FINAL SUMMARY FOR SCENARIO:", scenario, "\n")
cat("=====================================\n\n")

for (M in M_values) {
  cat("\nM =", M, ":\n")
  print(summary_tables[[paste0("M", M)]][, c("Method", "Relative_Bias", 
                                              "Relative_Efficiency", "Coverage")])
}

cat("\nSimulation completed successfully!\n")
