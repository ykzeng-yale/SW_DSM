##############################################################################
# Comprehensive Comparison: Baseline vs Survey-Weighted Matching Methods
# For PATE under Retrospective Sampling - McCleary HPC Version
# All methods estimate Population Average Treatment Effect (PATE)
# VARYING M = 1, 3, 5 (number of matches per unit)
# 
# IMPORTANT UPDATE: Testing differential weight normalization:
#   - PS Full (Survey-Weighted): Uses NORMALIZED weights w * length(w)/sum(w) 
#   - WDSM (Multinomial Bootstrap): Uses RAW weights (no normalization)
# This tests whether WDSM requires normalization like PS Full
#
# Comparing:
# 1. Unweighted DSM (dsmatch-master with bootstrap)
# 2. Unweighted PG matching (dsmatch-master with bootstrap) 
# 3. Unweighted PS matching (dsmatch-master with bootstrap)
# 4. Survey-weighted PS full matching (MatchIt with design-based inference)
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
# Function to run a single replicate (now loops over M values)
# ============================================================================
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M_values, B, alpha) {
  
  # Set timeout for this replicate (5 minutes per M value = 15 minutes total)
  setTimeLimit(cpu = 900, elapsed = 900)
  
  tryCatch({
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
    
    # Initialize results for all M values
    replicate_results <- list()
    
    # Loop over different M values
    for (M in M_values) {
      
      # Initialize results for this M value
      m_results <- list()
      
      # ============================================================
      # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch-master)
      # ============================================================
      tryCatch({
      # Create interaction term for consistency
      X_dsm <- cbind(X, X[,1] * X[,2])
      colnames(X_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      
      # Run DSM with bootstrap
      dsm_result <- dsmatchATE(
        Y = Y,
        X = X_dsm,  # Include interaction term
        A = A,
        method = "dsm",
        model.ps = "logit",    # Use logit (X already includes interaction)
        # lp.ps not needed with "logit"
        model.pg = "linpred",  # Use linear predictors
        lp.pg = X_dsm,         # All covariates including interaction
        cov.balance = FALSE,
        varest = TRUE,
        boots = B,
        mc = FALSE,  # Don't use internal multicore since we're already in parallel
        ncpus = 1
      )
      
      m_results$dsm_unweighted <- list(
        estimate = dsm_result$est.ds,
        se = sqrt(dsm_result$bootvar[1,1]),
        ci_lower = dsm_result$est.ds - qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1]),
        ci_upper = dsm_result$est.ds + qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1])
      )
      
    }, error = function(e) {
      cat("DSM Unweighted Error in replicate", i.rep, ", M=", M, ":", e$message, "\n")
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
      # Create interaction term for consistency
      X_pg <- cbind(X, X[,1] * X[,2])
      colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      
      # Run PG matching with bootstrap
      pg_result <- dsmatchATE(
        Y = Y,
        X = X_pg,
        A = A,
        method = "pg",
        model.pg = "linpred",  # Use linear predictors
        lp.pg = X_pg,          # All covariates including interaction
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
      # Create interaction term for consistency
      X_ps <- cbind(X, X[,1] * X[,2])
      colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      
      # Run PS matching with bootstrap using dsmatch-master
      ps_result <- dsmatchATE(
        Y = Y,
        X = X_ps,  # Include interaction term
        A = A,
        method = "ps",  # Propensity score matching
        model.ps = "logit",    # Use logit (X already includes interaction)
        # lp.ps not needed with "logit"
        cov.balance = FALSE,
        varest = TRUE,
        boots = B,
        mc = FALSE,  # Don't use internal multicore since we're already in parallel
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
        sw = w_normalized  # Using normalized survey weights (w * length(w) / sum(w))
      )
      
      # Run survey-weighted propensity score matching using full matching for ATE
      m_ps_sw <- matchit(
        A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
        data = match_data_sw,
        method = "full",      # Full matching supports ATE
        distance = "glm",     # Use standard logistic regression for PS estimation
        link = "logit",
        s.weights = ~ sw,     # Include survey weights in PS estimation
        estimand = "ATE"      # ATE estimation
      )
      
      # Extract matched data with combined weights
      # Use match.data for compatibility with McCleary MatchIt version
      md_sw <- match.data(m_ps_sw)
      
      # Fit outcome model with product weights
      # Following MatchIt vignette for marginal effects estimation
      fit_sw <- lm(Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2),
                   data = md_sw,
                   weights = weights)  # Product weights from match.data()
      
      # Estimate marginal ATE using g-computation
      # For retrospective sampling (PATE), use only sampling weights in wts
      ate_result <- avg_comparisons(
        fit_sw,
        variables = "A",
        vcov = ~subclass,    # Cluster on subclass for full matching
        wts = md_sw$sw       # Use only sampling weights for averaging (not product weights)
      )
      
      # Extract results
      m_results$ps_weighted <- list(
        estimate = ate_result$estimate,
        se = ate_result$std.error,
        ci_lower = ate_result$conf.low,
        ci_upper = ate_result$conf.high
      )
      
    }, error = function(e) {
      cat("PS Survey-Weighted Error in replicate", i.rep, ":", e$message, "\n")
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
      # IMPORTANT: Using RAW survey weights (not normalized) for WDSM
      # Testing hypothesis that WDSM doesn't require weight normalization
      
      # Compute estimate and CI using multinomial bootstrap
      ci_results <- compute_wdsm_method2_ci(
        Y = Y, A = A, X = X, weights = w_raw,  # Using RAW weights (not normalized)
        M = M,
        n_bootstrap = B,
        alpha = alpha,
        use_bias_correction = TRUE,
        return_samples = FALSE
      )
      
      m_results$wdsm_multinomial <- list(
        estimate = ci_results$estimate,
        se = ci_results$se,
        ci_lower = ci_results$ci_lower,
        ci_upper = ci_results$ci_upper
      )
      
    }, error = function(e) {
      cat("WDSM Multinomial Bootstrap Error in replicate", i.rep, ":", e$message, "\n")
      m_results$wdsm_multinomial <- list(
        estimate = NA,
        se = NA,
        ci_lower = NA,
        ci_upper = NA
      )
    })
    
      # Store results for this M value
      replicate_results[[paste0("M", M)]] <- m_results
      
    } # End of M loop
    
    # Remove time limit
    setTimeLimit(cpu = Inf, elapsed = Inf)
    
    return(replicate_results)
    
  }, error = function(e) {
    setTimeLimit(cpu = Inf, elapsed = Inf)
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
n_reps <- 1000    # Number of simulation replicates
n_sample <- 5000  # Sample size for retrospective sampling
M_values <- c(1, 3, 5)  # Number of matches per unit (varying)
B <- 200          # Bootstrap iterations
alpha <- 0.05     # Significance level

# Calculate true population PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("\nTrue Population PATE:", round(true_pate, 4), "\n")

# ============================================================================
# Main Simulation Loop with FORK Cluster
# ============================================================================
start_time <- Sys.time()

cat("\n============================================================\n")
cat("Running PATE Retrospective Sampling Comparison\n")
cat("============================================================\n")
cat("\nSample size:", n_sample, "\n")
cat("Number of replicates:", n_reps, "\n")
cat("Number of matches (M values):", paste(M_values, collapse=", "), "\n")
cat("Bootstrap iterations:", B, "\n")
cat("Significance level:", alpha, "\n")

# Set up parallel backend with FORK cluster for better stability
n_cores <- 20  # Optimal for McCleary
cat("\n============================================================\n")
cat("Setting up parallel backend with", n_cores, "cores (FORK cluster)...\n")
cat("============================================================\n")

cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
registerDoParallel(cl)

# Run simulation with larger batch size
batch_size <- 100  # Process in batches to prevent memory issues

cat("\nRunning simulation in batches of", batch_size, "replicates each...\n")
cat("============================================================\n")

# Run replicates in parallel with timeout protection
all_results <- foreach(i.rep = 1:n_reps,
                      .combine = 'c',
                      .multicombine = TRUE,
                      .maxcombine = batch_size,
                      .inorder = FALSE,
                      .errorhandling = 'pass',
                      .packages = c("survey", "sampling", "MatchIt", "MASS", 
                                   "boot", "nnet", "marginaleffects", "R.utils"),
                      .export = c("run_single_replicate", "population", "true_pate",
                                 "n_sample", "M_values", "B", "alpha",
                                 "retrospective_sample", "wdsm_point_estimate",
                                 "method2_multinomial_bootstrap_ci",
                                 "expit", "weighted_distance", "find_weighted_neighbors",
                                 "calculate_weighted_reuse_counts")) %dopar% {
  
  # Progress tracking
  if (i.rep %% 50 == 0) {
    cat("Starting replicate", i.rep, "of", n_reps, "\n")
  }
  
  # Set random seed for this replicate
  set.seed(20250127 + i.rep)
  
  # Run with memory management
  gc()  # Garbage collection before starting
  
  # Run single replicate with timeout protection
  result <- R.utils::withTimeout({
    run_single_replicate(i.rep, population, true_pate, n_sample, M_values, B, alpha)
  }, timeout = 900, onTimeout = "error")
  
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
cat("FINAL RESULTS SUMMARY - PATE RETROSPECTIVE SAMPLING\n")
cat("Varying M =", paste(M_values, collapse=", "), "\n")
cat("============================================================\n")

# Extract results for analysis
methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
            "ps_weighted", "wdsm_multinomial")
method_names <- c("DSM (Unweighted)", "PG (Unweighted)", "PS (Unweighted)",
                 "PS Full (Survey-Weighted)", "WDSM (Multinomial Bootstrap)")

# Process results for each M value
all_summary_stats <- list()

for (M in M_values) {
  M_label <- paste0("M", M)
  cat("\n\n------------------------------------------------------------\n")
  cat("Results for M =", M, "\n")
  cat("------------------------------------------------------------\n")
  
  # Build matrix of estimates for all methods for this M
  est_mat <- tryCatch({
    sapply(methods, function(m) {
      sapply(all_results, function(res) {
        if (!is.null(res[[M_label]][[m]]$estimate)) {
          res[[M_label]][[m]]$estimate
        } else {
          NA
        }
      })
    })
  }, error = function(e) NULL)
  
  # Ensure all methods are evaluated on same replicates
  # Remove rows with ANY missing values
  if (!is.null(est_mat)) {
    complete_rows <- apply(!is.na(est_mat), 1, all)
    est_mat_complete <- est_mat[complete_rows, , drop = FALSE]
    n_complete <- nrow(est_mat_complete)
    
    cat("\nUsing", n_complete, "complete replicates out of", n_reps, "total\n")
  
  # Calculate empirical (Monte Carlo) variances
  emp_var <- apply(est_mat_complete, 2, var)
  emp_sd <- sqrt(emp_var)
  
  # Choose PS (Unweighted) as reference (column 3)
  ref_idx <- 3  # PS (Unweighted)
  ref_method <- methods[ref_idx]
  rel_eff_var <- emp_var[ref_idx] / emp_var
  
  # Initialize summary statistics
  summary_stats <- data.frame(
    Method = method_names,
    Mean_Estimate = numeric(length(methods)),
    Bias = numeric(length(methods)),
    Mean_SE = numeric(length(methods)),
    Empirical_SD = emp_sd,  # Use empirical SD from complete cases
    Relative_Bias = numeric(length(methods)),
    Relative_Efficiency = rel_eff_var,  # Variance-based relative efficiency
    Coverage = numeric(length(methods)),
    CI_Width = numeric(length(methods))
  )
  
  # Calculate other summary statistics using complete cases
  for (i in seq_along(methods)) {
    method <- methods[i]
    
    # Use only complete cases
    valid_idx <- which(complete_rows)
    
    # Extract values for complete cases only
    estimates <- est_mat_complete[, i]
    ses <- sapply(valid_idx, function(j) all_results[[j]][[M_label]][[method]]$se)
    ci_lowers <- sapply(valid_idx, function(j) all_results[[j]][[M_label]][[method]]$ci_lower)
    ci_uppers <- sapply(valid_idx, function(j) all_results[[j]][[M_label]][[method]]$ci_upper)
    
    # Mean estimate and bias
    summary_stats$Mean_Estimate[i] <- mean(estimates)
    summary_stats$Bias[i] <- mean(estimates) - true_pate
    
    # Mean SE
    summary_stats$Mean_SE[i] <- mean(ses, na.rm = TRUE)
    
    # Relative bias (relative to true PATE)
    summary_stats$Relative_Bias[i] <- (mean(estimates) - true_pate) / abs(true_pate)
    
    # Coverage
    coverage <- mean(ci_lowers <= true_pate & ci_uppers >= true_pate)
    summary_stats$Coverage[i] <- coverage
    
    # Average CI width
    summary_stats$CI_Width[i] <- mean(ci_uppers - ci_lowers)
  }
  
    # Print summary table
    cat("\n")
    print(summary_stats, digits = 4)
    
    # Store summary for this M value
    summary_stats$M <- M
    all_summary_stats[[M_label]] <- summary_stats
    
  } else {
    cat("Warning: Could not build estimate matrix for M =", M, ". Using fallback method.\n")
    n_complete <- 0
    summary_stats <- data.frame(
      Method = method_names,
      Mean_Estimate = NA,
      Mean_SE = NA,
      Empirical_SD = NA,
      Relative_Bias = NA,
      Relative_Efficiency = NA,
      Coverage = NA,
      CI_Width = NA,
      M = M
    )
    all_summary_stats[[M_label]] <- summary_stats
  }
} # End of M loop

# Combine all M summaries into one data frame
combined_summary <- do.call(rbind, all_summary_stats)

# Save results (with normalized weights)
save(all_results, all_summary_stats, combined_summary, true_pate, n_sample, n_reps, M_values, B,
     file = "pate_retrospective_comparison_results_mccleary_M135_rawWDSM.RData")
cat("\n\nResults saved to 'pate_retrospective_comparison_results_mccleary_M135_rawWDSM.RData'\n")

# ============================================================================
# Create visualization
# ============================================================================
if (length(all_summary_stats) > 0) {
  library(ggplot2)
  library(tidyr)
  library(dplyr)
  
  # Prepare data for plotting - combine all M values
  plot_data <- combined_summary %>%
    select(Method, M, Relative_Bias, Relative_Efficiency, Coverage) %>%
    pivot_longer(cols = c(Relative_Bias, Relative_Efficiency, Coverage),
                 names_to = "Metric",
                 values_to = "Value") %>%
    mutate(M = factor(M, levels = M_values))
  
  # Create comparison plot with M as facet
  p <- ggplot(plot_data, aes(x = Method, y = Value, fill = Method)) +
    geom_bar(stat = "identity") +
    facet_grid(M ~ Metric, scales = "free_y", labeller = label_both) +
    theme_minimal(base_size = 10) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
      legend.position = "none",
      strip.text = element_text(face = "bold", size = 10)
    ) +
    labs(
      title = "Comparison of Matching Methods: PATE under Retrospective Sampling",
      subtitle = sprintf("True PATE = %.4f | Sample size = %d | N replicates = %d | M = %s | B = %d",
                        true_pate, n_sample, n_reps, paste(M_values, collapse=","), B),
      y = "Value",
      x = ""
    ) +
    scale_fill_brewer(palette = "Set3")
  
  # Add reference lines
  p <- p + 
    geom_hline(data = filter(plot_data, Metric == "Coverage"),
               aes(yintercept = 0.95), linetype = "dashed", color = "red", size = 0.5) +
    geom_hline(data = filter(plot_data, Metric == "Relative_Bias"),
               aes(yintercept = 0), linetype = "dashed", color = "red", size = 0.5) +
    geom_hline(data = filter(plot_data, Metric == "Relative_Efficiency"),
               aes(yintercept = 1), linetype = "dashed", color = "red", size = 0.5)
  
  # Save plot
  ggsave("pate_retrospective_comparison_plot_mccleary_M135_rawWDSM.pdf", p, width = 14, height = 10)
  cat("\nPlot saved to 'pate_retrospective_comparison_plot_mccleary_M135_rawWDSM.pdf'\n")
}

# ============================================================================
# Create detailed results table
# ============================================================================
detailed_results <- data.frame(
  M = combined_summary$M,
  Method = combined_summary$Method,
  Estimate = sprintf("%.4f", combined_summary$Mean_Estimate),
  Bias = sprintf("%.4f", combined_summary$Bias),
  SE = sprintf("%.4f", combined_summary$Mean_SE),
  Emp_SD = sprintf("%.4f", combined_summary$Empirical_SD),
  Bias_Percent = sprintf("%.1f%%", combined_summary$Relative_Bias * 100),
  Var_Rel_Eff = sprintf("%.2f", combined_summary$Relative_Efficiency),
  Coverage = sprintf("%.1f%%", combined_summary$Coverage * 100),
  CI_Width = sprintf("%.4f", combined_summary$CI_Width)
)

cat("\n\nDetailed Results Table (All M values):\n")
cat("(Variance-Based Relative Efficiency: >1 means more efficient than PS Unweighted)\n")
print(detailed_results, row.names = FALSE)

# Save detailed results
write.csv(detailed_results, "pate_retrospective_comparison_table_mccleary_M135_rawWDSM.csv", row.names = FALSE)
cat("\n\nDetailed results table saved to 'pate_retrospective_comparison_table_mccleary_M135_rawWDSM.csv'\n")

# ============================================================================
# Additional diagnostics
# ============================================================================
cat("\n\nDiagnostic Summary:\n")
cat("================\n")

# Check convergence rates
for (i in seq_along(methods)) {
  method <- methods[i]
  estimates <- sapply(all_results, function(x) {
    if (!is.null(x[[method]]$estimate)) {
      x[[method]]$estimate
    } else {
      NA
    }
  })
  n_failed <- sum(is.na(estimates))
  
  if (n_failed > 0) {
    cat(sprintf("%s: %d out of %d replicates failed (%.1f%%)\n",
                method_names[i], n_failed, n_reps, 100*n_failed/n_reps))
  }
}

# Report computation time and completeness
cat("\nComplete replicates used for variance calculation:", n_complete, "out of", n_reps, "\n")
cat("Total computation time:", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")
cat("Average time per replicate:", round(difftime(end_time, start_time, units = "secs") / n_reps, 2), "seconds\n")

# ============================================================================
# Create bias-variance plot
# ============================================================================
if (!is.null(est_mat_complete) && n_complete > 0) {
  bv_data <- summary_stats %>%
    mutate(
      Bias_Squared = Bias^2,
      Variance = Empirical_SD^2,
      MSE = Bias_Squared + Variance
    ) %>%
    select(Method, Bias_Squared, Variance, MSE) %>%
    pivot_longer(cols = c(Bias_Squared, Variance, MSE),
                 names_to = "Component",
                 values_to = "Value")
  
  p_bv <- ggplot(bv_data, aes(x = Method, y = Value, fill = Component)) +
    geom_bar(stat = "identity", position = position_dodge()) +
    theme_minimal(base_size = 12) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "top"
    ) +
    labs(
      title = "Bias-Variance Decomposition",
      subtitle = "Mean Squared Error = Bias² + Variance",
      y = "Value",
      x = ""
    ) +
    scale_fill_brewer(palette = "Set2")
  
  ggsave("pate_retrospective_bias_variance_plot_mccleary.pdf", p_bv, width = 10, height = 6)
  cat("\nBias-variance plot saved to 'pate_retrospective_bias_variance_plot_mccleary.pdf'\n")
}

cat("\n============================================================\n")
cat("Analysis Complete!\n")
cat("============================================================\n")