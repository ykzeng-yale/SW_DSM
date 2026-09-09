##############################################################################
# Comprehensive Comparison: Baseline vs Survey-Weighted Matching Methods
# For PATE under Retrospective Sampling
# All methods estimate Population Average Treatment Effect (PATE)
# Comparing:
# 1. Unweighted DSM (dsmatch-master with bootstrap)
# 2. Unweighted PG matching (dsmatch-master with bootstrap) 
# 3. Unweighted PS matching (dsmatch-master with bootstrap)
# 4. Survey-weighted PS full matching (MatchIt with design-based inference)
# 5. WDSM with Multinomial Bootstrap for retrospective sampling
##############################################################################

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
# library(glmnet)  # No longer needed - using standard GLM
library(marginaleffects)

# Set seed for reproducibility
set.seed(20250127)

# Setup parallel processing
n_cores <- 1  # Use 1 core (no parallel processing)
cl <- makeCluster(n_cores)
registerDoParallel(cl)

# Load dsmatch package
devtools::load_all("dsmatch-master")

# Source required functions
source("wdsm_method2_multinomial_bootstrap.R")  # Load WDSM Multinomial Bootstrap
source("wdsm_ci_functions.R")  # For retrospective_sample and wdsm_point_estimate

# Note: The following functions are loaded from external sources:
# - dsmatchATE: from dsmatch-master package
# - retrospective_sample, wdsm_point_estimate: from wdsm_ci_functions.R
# - method2_multinomial_bootstrap_ci: from wdsm_method2_multinomial_bootstrap.R

# ============================================================================
# Function to run a single replicate
# ============================================================================
run_single_replicate <- function(i.rep, population, true_pate, n_sample, M, B, alpha) {
  
  # Retrospective sampling
  sample <- retrospective_sample(population, n_sample = n_sample)
  
  # Extract variables
  Y <- sample$Y
  X <- as.matrix(sample[, c("X1", "X2", "X3", "X4", "X5", "X6")])
  A <- sample$A
  w_raw <- sample$survey_weight
  
  # CRITICAL: Normalize survey weights to sum to sample size
  # This is essential for proper variance estimation
  w <- w_raw * length(w_raw) / sum(w_raw)
  
  # Initialize results for this replicate
  replicate_results <- list()
  
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
    
    replicate_results$dsm_unweighted <- list(
      estimate = dsm_result$est.ds,
      se = sqrt(dsm_result$bootvar[1,1]),
      ci_lower = dsm_result$est.ds - qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1]),
      ci_upper = dsm_result$est.ds + qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1])
    )
    
  }, error = function(e) {
    cat("DSM Unweighted Error:", e$message, "\n")
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
    
    replicate_results$pg_unweighted <- list(
      estimate = pg_result$est.pg,
      se = sqrt(pg_result$bootvar[1,1]),
      ci_lower = pg_result$est.pg - qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1]),
      ci_upper = pg_result$est.pg + qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1])
    )
    
  }, error = function(e) {
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
    
    replicate_results$ps_unweighted <- list(
      estimate = ps_result$est.ps,
      se = sqrt(ps_result$bootvar[1,1]),
      ci_lower = ps_result$est.ps - qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1]),
      ci_upper = ps_result$est.ps + qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1])
    )
    
  }, error = function(e) {
    replicate_results$ps_unweighted <- list(
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
    # Create data frame with weights
    match_data_sw <- data.frame(
      Y = Y,
      A = A,
      X1 = X[,1],
      X2 = X[,2],
      X3 = X[,3],
      X4 = X[,4],
      X5 = X[,5],
      X6 = X[,6],
      sw = w
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
    md_sw <- match_data(m_ps_sw)
    
    # Fit outcome model with product weights
    # Following MatchIt vignette for marginal effects estimation
    library(marginaleffects)
    fit_sw <- lm(Y ~ A * (X1 + X2 + X3 + X4 + X5 + X6 + X1:X2),
                 data = md_sw,
                 weights = weights)  # Product weights from match_data()
    
    # Estimate marginal ATE using g-computation
    # For retrospective sampling (PATE), use only sampling weights in wts
    ate_result <- avg_comparisons(
      fit_sw,
      variables = "A",
      vcov = ~subclass,    # Cluster on subclass for full matching
      wts = md_sw$sw       # Use only sampling weights for averaging (not product weights)
    )
    
    # Extract results
    replicate_results$ps_weighted <- list(
      estimate = ate_result$estimate,
      se = ate_result$std.error,
      ci_lower = ate_result$conf.low,
      ci_upper = ate_result$conf.high
    )
    
  }, error = function(e) {
    cat("PS Survey-Weighted Error:", e$message, "\n")
    replicate_results$ps_weighted <- list(
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
    # Note: Variables Y, X, A, w already extracted and normalized above
    # No need to re-extract, using the normalized weights
    
    # Compute estimate and CI using multinomial bootstrap
    ci_results <- compute_wdsm_method2_ci(
      Y = Y, A = A, X = X, weights = w,
      M = M,
      n_bootstrap = B,
      alpha = alpha,
      use_bias_correction = TRUE,
      return_samples = FALSE
    )
    
    replicate_results$wdsm_multinomial <- list(
      estimate = ci_results$estimate,
      se = ci_results$se,
      ci_lower = ci_results$ci_lower,
      ci_upper = ci_results$ci_upper
    )
    
  }, error = function(e) {
    cat("WDSM Multinomial Bootstrap Error:", e$message, "\n")
    replicate_results$wdsm_multinomial <- list(
      estimate = NA,
      se = NA,
      ci_lower = NA,
      ci_upper = NA
    )
  })
  
  return(replicate_results)
}

# ============================================================================
# Load Population Data
# ============================================================================
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
n_reps <- 10      # Number of simulation replicates (reduced for testing)
n_sample <- 5000  # Sample size for retrospective sampling
M <- 5            # Number of matches per unit
B <- 200          # Bootstrap iterations
alpha <- 0.05     # Significance level

# Calculate true population PATE
true_pate <- mean(population$Y1 - population$Y0)
cat("\nTrue Population PATE:", round(true_pate, 4), "\n")

# ============================================================================
# Main Simulation Loop
# ============================================================================
start_time <- Sys.time()

cat("\n============================================================\n")
cat("Running PATE Retrospective Sampling Comparison\n")
cat("============================================================\n")
cat("\nSample size:", n_sample, "\n")
cat("Running", n_reps, "replicates in parallel using", n_cores, "cores...\n")

# Export required functions to cluster
clusterExport(cl, c("expit", "show_progress", "retrospective_sample",
                    "weighted_distance", "find_weighted_neighbors",
                    "calculate_weighted_reuse_counts", "wdsm_point_estimate",
                    "method2_multinomial_bootstrap_ci"))

# Run replicates in parallel
all_results <- foreach(i.rep = 1:n_reps,
                      .packages = c("survey", "sampling", "MatchIt", "MASS", 
                                   "boot", "nnet", "marginaleffects"),
                      .export = c("dsmatchATE", "run_single_replicate", 
                                 "match_data")) %dopar% {
  
  # Set random seed for this replicate
  set.seed(20250127 + i.rep)
  
  # Run single replicate
  result <- run_single_replicate(i.rep, population, true_pate, 
                                n_sample, M, B, alpha)
  
  return(result)
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
cat("============================================================\n")

# Extract results for analysis
methods <- c("dsm_unweighted", "pg_unweighted", "ps_unweighted", 
            "ps_weighted", "wdsm_multinomial")
method_names <- c("DSM (Unweighted)", "PG (Unweighted)", "PS (Unweighted)",
                 "PS Full (Survey-Weighted)", "WDSM (Multinomial Bootstrap)")

# Build matrix of estimates for all methods
est_mat <- sapply(methods, function(m) 
                  sapply(all_results, function(res) res[[m]]$estimate))

# Ensure all methods are evaluated on same replicates
# Remove rows with ANY missing values
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
  ses <- sapply(valid_idx, function(j) all_results[[j]][[method]]$se)
  ci_lowers <- sapply(valid_idx, function(j) all_results[[j]][[method]]$ci_lower)
  ci_uppers <- sapply(valid_idx, function(j) all_results[[j]][[method]]$ci_upper)
  
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

# Save results
save(all_results, summary_stats, true_pate, n_sample, n_reps, M, B,
     file = "pate_retrospective_comparison_results.RData")
cat("\n\nResults saved to 'pate_retrospective_comparison_results.RData'\n")

# ============================================================================
# Create visualization
# ============================================================================
library(ggplot2)
library(tidyr)
library(dplyr)

# Prepare data for plotting
plot_data <- summary_stats %>%
  select(Method, Relative_Bias, Relative_Efficiency, Coverage) %>%
  pivot_longer(cols = c(Relative_Bias, Relative_Efficiency, Coverage),
               names_to = "Metric",
               values_to = "Value")

# Create comparison plot
p <- ggplot(plot_data, aes(x = Method, y = Value, fill = Method)) +
  geom_bar(stat = "identity") +
  facet_wrap(~Metric, scales = "free_y", nrow = 1) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none",
    strip.text = element_text(face = "bold", size = 14)
  ) +
  labs(
    title = "Comparison of Matching Methods: PATE under Retrospective Sampling",
    subtitle = sprintf("True PATE = %.4f | Sample size = %d | N replicates = %d | M = %d | B = %d",
                      true_pate, n_sample, n_reps, M, B),
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
ggsave("pate_retrospective_comparison_plot.pdf", p, width = 12, height = 6)
cat("\nPlot saved to 'pate_retrospective_comparison_plot.pdf'\n")

# ============================================================================
# Create detailed results table
# ============================================================================
detailed_results <- data.frame(
  Method = summary_stats$Method,
  Estimate = sprintf("%.4f", summary_stats$Mean_Estimate),
  Bias = sprintf("%.4f", summary_stats$Bias),
  SE = sprintf("%.4f", summary_stats$Mean_SE),
  Emp_SD = sprintf("%.4f", summary_stats$Empirical_SD),
  Bias_Percent = sprintf("%.1f%%", summary_stats$Relative_Bias * 100),
  Var_Rel_Eff = sprintf("%.2f", summary_stats$Relative_Efficiency),
  Coverage = sprintf("%.1f%%", summary_stats$Coverage * 100),
  CI_Width = sprintf("%.4f", summary_stats$CI_Width)
)

cat("\n\nDetailed Results Table:\n")
cat("(Variance-Based Relative Efficiency: >1 means more efficient than PS Unweighted)\n")
print(detailed_results, row.names = FALSE)

# Save detailed results
write.csv(detailed_results, "pate_retrospective_comparison_table.csv", row.names = FALSE)
cat("\n\nDetailed results table saved to 'pate_retrospective_comparison_table.csv'\n")

# ============================================================================
# Additional diagnostics
# ============================================================================
cat("\n\nDiagnostic Summary:\n")
cat("================\n")

# Check convergence rates
for (i in seq_along(methods)) {
  method <- methods[i]
  estimates <- sapply(all_results, function(x) x[[method]]$estimate)
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

ggsave("pate_retrospective_bias_variance_plot.pdf", p_bv, width = 10, height = 6)
cat("\nBias-variance plot saved to 'pate_retrospective_bias_variance_plot.pdf'\n")

cat("\n============================================================\n")
cat("Analysis Complete!\n")
cat("============================================================\n")