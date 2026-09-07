# Comprehensive Comparison: CorCor Scenario (Both PS and PGS Correct)
# Testing multiple matching counts (M=5 only) in each replicate
# Model Specification: Both models include interaction term X1:X2
# 100 replications version with 20 cores

# ============================================================================
# Setup and Libraries
# ============================================================================
cat("\n============================================================\n")
cat("Loading required packages...\n")
cat("============================================================\n")

# Load required packages
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
library(Matching)  # Required for dsmatch functions

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
source("wdsm_version11_final.R")

# ============================================================================
# Function to run a single replicate with multiple M values - CorCor only
# ============================================================================
run_single_replicate <- function(i.rep, data, true_pate, M_values, B, alpha) {
  
  tryCatch({
    # Load required libraries for parallel workers
    library(Matching)
    
    # Source dsmatch functions inside the worker (for parallel execution)
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
    
    # Multi-stage sampling
    size1 <- rep(100000, 10)
    size2 <- rep(5, 10)
    size3 <- c(rep(850 / 5, 5), rep(750 / 5, 5), rep(700 / 5, 5), rep(650 / 5, 5), 
               rep(600 / 5, 5), rep(400 / 5, 5), rep(350 / 5, 5), rep(300 / 5, 5), 
               rep(250 / 5, 5), rep(150 / 5, 5))
    
    s <- mstage(data, stage = list("stratified", "cluster", ""), 
                varnames = list("Strata", "Cluster", "ones"), 
                size = list(size1, size2, size3), 
                method = list("", "srswor", "srswor"))
    
    sample <- getdata(data, s)[[3]]
    
    # Add survey weights
    sample$s.wt <- 1 / sample$Prob
    
    # Extract variables
    Y <- sample$y
    X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
    A <- sample$z
    w <- sample$s.wt
    
    # Store sample size info
    n_sample <- nrow(sample)
    n_treated <- sum(A == 1)
    n_control <- sum(A == 0)
    
    # Initialize results for this replicate
    replicate_results <- list()
    
    # CorCor scenario: Both PS and PGS correct (include X1:X2)
    include_ps_interaction <- TRUE
    include_pgs_interaction <- TRUE
    
    # Loop over different M values
    for (M in M_values) {
      # Initialize results for this M value
      m_results <- list()
      m_results$M <- M
      m_results$model_spec <- "CorCor"
      
      # ============================================================
      # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch-master)
      # ============================================================
      tryCatch({
        # Create design matrix with interaction term (both correct)
        X_dsm <- cbind(X, X[,1] * X[,2])
        colnames(X_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
        
        # Run DSM with bootstrap
        dsm_result <- dsmatchATE(
          Y = Y,
          X = X_dsm,
          A = A,
          method = "dsm",
          model.ps = "logit",
          model.pg = "linpred",
          lp.pg = X_dsm,
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
        # Create design matrix with interaction term
        X_pg <- cbind(X, X[,1] * X[,2])
        colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
        
        # Run PG matching with bootstrap
        pg_result <- dsmatchATE(
          Y = Y,
          X = X_pg,
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
        # Create design matrix with interaction term
        X_ps <- cbind(X, X[,1] * X[,2])
        colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
        
        # Run PS matching with bootstrap
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
        # Create data frame with NORMALIZED weights
        w_normalized_ps <- w * length(w) / sum(w)
        
        match_data_sw <- data.frame(
          Y = Y,
          A = A,
          x1 = X[,1],
          x2 = X[,2],
          x3 = X[,3],
          x4 = X[,4],
          x5 = X[,5],
          x6 = X[,6],
          sw = w_normalized_ps
        )
        
        # PS formula with interaction term (correct specification)
        ps_formula <- A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2
        
        # Run survey-weighted propensity score matching
        m_ps_sw <- matchit(
          ps_formula,
          data = match_data_sw,
          method = "full",
          distance = "glm",
          link = "logit",
          s.weights = ~ sw,
          estimand = "ATE"
        )
        
        # Extract matched data
        md_sw <- match.data(m_ps_sw)
        
        # Fit outcome model with interaction term
        fit_sw <- lm(Y ~ A * (x1 + x2 + x3 + x4 + x5 + x6 + x1:x2), 
                     data = md_sw,
                     weights = weights)
        
        # Compute marginal ATE
        ate_result <- avg_comparisons(
          fit_sw,
          variables = "A",
          vcov = ~subclass,
          wts = "sw"
        )
        
        # Extract results
        m_results$ps_weighted <- list(
          estimate = ate_result$estimate[1],
          se = ate_result$std.error[1],
          ci_lower = ate_result$conf.low[1],
          ci_upper = ate_result$conf.high[1]
        )
        
      }, error = function(e) {
        cat("PS Survey-Weighted Error:", e$message, "\n")
        m_results$ps_weighted <- list(
          estimate = NA,
          se = NA,
          ci_lower = NA,
          ci_upper = NA
        )
      })
      
      # ============================================================
      # METHOD 5: SURVEY-WEIGHTED DOUBLE SCORE MATCHING (WDSM V11 Final)
      # ============================================================
      tryCatch({
        # Use WDSM v11 final with correct specifications
        wdsm_result <- wdsm_version11_final(
          Y = Y, 
          X = X,
          A = A, 
          w = w,
          M = M, 
          B = B, 
          alpha = alpha,
          verbose = FALSE,
          include_ps_interaction = TRUE,   # CorCor: PS correct
          include_pgs_interaction = TRUE   # CorCor: PGS correct
        )
        
        m_results$dsm_weighted <- list(
          estimate = wdsm_result$estimate,
          se = wdsm_result$se,
          ci_lower = wdsm_result$ci_lower,
          ci_upper = wdsm_result$ci_upper
        )
        
      }, error = function(e) {
        m_results$dsm_weighted <- list(
          estimate = NA,
          se = NA,
          ci_lower = NA,
          ci_upper = NA
        )
      })
      
      # Store results for this M value
      replicate_results[[paste0("M", M)]] <- m_results
    }  # End of M loop
    
    return(replicate_results)
    
  }, error = function(e) {
    return(list(error = paste("Replicate", i.rep, "failed:", e$message)))
  })
}

# ============================================================================
# Main Simulation
# ============================================================================

# Set parameters
M_values <- c(5)  # Multiple matching counts to test
B <- 200          # Bootstrap iterations
alpha <- 0.05     # Significance level
n_reps <- 1000    # Number of replicates (1000-rep for li_fan account) (reduced version)

# Record start time
start_time <- Sys.time()

cat("\n============================================================\n")
cat("SIMULATION PARAMETERS - CorCor Scenario:\n")
cat("============================================================\n")
cat("Model Specification: Both PS and PGS Correct (include X1:X2)\n")
cat("Number of replicates:", n_reps, "\n")
cat("Matching counts (M):", paste(M_values, collapse=", "), "\n")
cat("Bootstrap iterations:", B, "\n")
cat("Significance level:", alpha, "\n")

# Load population data
cat("\n============================================================\n")
cat("Loading population data...\n")
cat("============================================================\n")

# Load the specific scenario data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_GoodOverlap_AllinOne_0118_2025

# Access scenario 1 data (good overlap)
data <- data_sets[[1]]

# Add necessary columns
data$ones <- 1
data$id <- 1:nrow(data)

# Calculate true population PATE
true_pate <- mean(data$y1) - mean(data$y0)
cat("True Population PATE:", round(true_pate, 4), "\n")

# Set up parallel backend with FORK cluster
n_cores <- 20
cat("\n============================================================\n")
cat("Setting up parallel backend with", n_cores, "cores (FORK cluster)...\n")
cat("============================================================\n")

cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log_CorCor.txt")
registerDoParallel(cl)

# Run simulation
batch_size <- 20
n_batches <- ceiling(n_reps / batch_size)

cat("\n============================================================\n")
cat("Running CorCor simulation in", n_batches, "batches of", batch_size, "replicates each...\n")
cat("============================================================\n")

all_results <- foreach(i = 1:n_reps, 
                      .combine = 'c',
                      .multicombine = TRUE,
                      .maxcombine = 100,
                      .inorder = FALSE,
                      .errorhandling = 'pass',
                      .packages = c('survey', 'sampling', 'MASS', 'nnet', 
                                  'MatchIt', 'marginaleffects', 'boot', 'Matching'),
                      .export = c('run_single_replicate', 'wdsm_version11_final',
                                'dsmatchATE', 'estforboot_dsATE', 'estforboot_psATE', 
                                'estforboot_pgATE', 'estforboot_covATE', 'is.lp', 'is.ps', 
                                'is.pg', 'bisect',
                                'data', 'true_pate', 'M_values', 'B', 'alpha')) %dopar% {
  
  # Progress tracking
  if (i %% 20 == 0) {
    cat("Starting replicate", i, "of", n_reps, "\n")
  }
  
  set.seed(1000 + i)  # Use same seeds as successful all scenarios run
  
  # Run with memory management
  gc()
  
  result <- run_single_replicate(i, data, true_pate, M_values, B, alpha)
  
  gc()
  
  list(result)
}

# Stop cluster
stopCluster(cl)

# Record end time
end_time <- Sys.time()
cat("\nTotal runtime:", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")

# ============================================================================
# Analyze Results for Each M Value
# ============================================================================
cat("\n\n============================================================\n")
cat("FINAL RESULTS SUMMARY - CorCor Scenario\n")
cat("============================================================\n")

# Extract results for analysis
methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", "ps_weighted", "dsm_weighted")
method_names <- c("DSM (Unweighted)", "PG (Unweighted)", "PS (Unweighted)", 
                  "PS Full (Survey-Weighted)", "DSM (Survey-Weighted)")

# Store results for each M value
results_by_M <- list()

# Process results for each M value
for (M in M_values) {
  cat("\n\n----------------------------------------\n")
  cat("Results for M =", M, "(CorCor)\n")
  cat("----------------------------------------\n")
  
  # Build matrix of estimates
  est_mat <- tryCatch({
    sapply(methods, function(m) {
      sapply(all_results, function(res) {
        if (!is.null(res[[paste0("M", M)]][[m]]$estimate)) {
          res[[paste0("M", M)]][[m]]$estimate
        } else {
          NA
        }
      })
    })
  }, error = function(e) NULL)

  se_mat <- tryCatch({
    sapply(methods, function(m) {
      sapply(all_results, function(res) {
        if (!is.null(res[[paste0("M", M)]][[m]]$se)) {
          res[[paste0("M", M)]][[m]]$se
        } else {
          NA
        }
      })
    })
  }, error = function(e) NULL)
  
  ci_lower_mat <- tryCatch({
    sapply(methods, function(m) {
      sapply(all_results, function(res) {
        if (!is.null(res[[paste0("M", M)]][[m]]$ci_lower)) {
          res[[paste0("M", M)]][[m]]$ci_lower
        } else {
          NA
        }
      })
    })
  }, error = function(e) NULL)
  
  ci_upper_mat <- tryCatch({
    sapply(methods, function(m) {
      sapply(all_results, function(res) {
        if (!is.null(res[[paste0("M", M)]][[m]]$ci_upper)) {
          res[[paste0("M", M)]][[m]]$ci_upper
        } else {
          NA
        }
      })
    })
  }, error = function(e) NULL)

  # Remove rows with any NAs
  if (!is.null(est_mat)) {
    good_rows <- apply(!is.na(est_mat), 1, all)
    est_mat_clean <- est_mat[good_rows, , drop = FALSE]
    se_mat_clean <- se_mat[good_rows, , drop = FALSE]
    ci_lower_mat_clean <- ci_lower_mat[good_rows, , drop = FALSE]
    ci_upper_mat_clean <- ci_upper_mat[good_rows, , drop = FALSE]
    
    cat("\nNumber of valid replicates (all methods):", sum(good_rows), "out of", length(good_rows), "\n")
    
    # Compute empirical variances
    emp_var <- apply(est_mat_clean, 2, var)
    emp_sd <- sqrt(emp_var)
    
    # Calculate relative efficiency
    ref_idx <- 3  # ps_unweighted
    rel_eff_var <- emp_var[ref_idx] / emp_var
    
    # Initialize summary statistics
    summary_stats <- data.frame(
      M = M,
      Model_Spec = "CorCor",
      Method = method_names,
      Mean_Estimate = apply(est_mat_clean, 2, mean),
      Mean_SE = apply(se_mat_clean, 2, mean),
      Empirical_SE = emp_sd,
      SE_Ratio = apply(se_mat_clean, 2, mean) / emp_sd,
      Relative_Bias = (apply(est_mat_clean, 2, mean) - true_pate) / true_pate,
      Relative_Efficiency = rel_eff_var,
      Coverage = apply(ci_lower_mat_clean <= true_pate & ci_upper_mat_clean >= true_pate, 2, mean),
      N_Valid = sum(good_rows)
    )
    
  } else {
    cat("Warning: Could not build estimate matrix for M =", M, "\n")
    summary_stats <- data.frame(
      M = M,
      Model_Spec = "CorCor",
      Method = method_names,
      Mean_Estimate = NA,
      Mean_SE = NA,
      Empirical_SE = NA,
      SE_Ratio = NA,
      Relative_Bias = NA,
      Relative_Efficiency = NA,
      Coverage = NA,
      N_Valid = 0
    )
  }
  
  # Print summary table
  cat("\n")
  print(summary_stats)
  
  # Store results
  results_by_M[[paste0("M", M)]] <- summary_stats
}

# Combine all results
all_summary_stats <- do.call(rbind, results_by_M)

# Save results
save(all_results, results_by_M, all_summary_stats, true_pate,
     file = "comprehensive_M5_CorCor_1000rep_lifan_results.RData")

cat("\n\nResults saved to 'comprehensive_M5_CorCor_1000rep_lifan_results.RData'\n")

# Save detailed results table
write.csv(all_summary_stats, "comprehensive_M5_CorCor_1000rep_lifan_table.csv", row.names = FALSE)
cat("Detailed results table saved to 'comprehensive_M5_CorCor_1000rep_lifan_table.csv'\n")

cat("\n============================================================\n")
cat("SIMULATION FOR CorCor SCENARIO COMPLETED!\n")
cat("============================================================\n")
