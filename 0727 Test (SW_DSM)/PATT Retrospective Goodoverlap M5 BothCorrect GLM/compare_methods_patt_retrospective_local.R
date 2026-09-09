#!/usr/bin/env Rscript
# ==============================================================================
# Title: Comprehensive Comparison - PATT Retrospective Sampling
# Author: WDSM Research Team
# Date: 2025-01-28
# Description:
#   Comparing matching methods for PATT under retrospective sampling:
#   1. Unweighted DSM (dsmatch-master with bootstrap)
#   2. Unweighted PS matching (dsmatch-master with bootstrap)
#   3. Unweighted PG matching (dsmatch-master with bootstrap)
#   4. Survey-weighted PS full matching (MatchIt with marginaleffects)
#   5. Survey-weighted DSM Version 2 with standard GLM/LM (wdsm_patt_v2_standard.R)
# ==============================================================================

# Load required libraries
library(MASS)
library(MatchIt)
library(marginaleffects)  # For proper ATT estimation with survey weights
library(parallel)
library(doParallel)
library(foreach)
library(boot)

# Set seed for reproducibility
set.seed(20250128)

# Setup parallel processing
n_cores <- 2  # Use 2 cores for parallel processing
cl <- makeCluster(n_cores)
registerDoParallel(cl)

# Load dsmatch package
devtools::load_all("dsmatch-master")

# Check if optmatch is available for full matching
if (!requireNamespace("optmatch", quietly = TRUE)) {
  warning("optmatch package not available. Full matching may not work properly.")
}

# Source our V2 WDSM function (standard GLM/LM version)
source("wdsm_patt_v2_standard.R")

# ============================================================================
# Helper Functions
# ============================================================================

# Expit function (for retrospective sampling probabilities)
expit <- function(x) {
  exp(x) / (1 + exp(x))
}

# ============================================================================
# Function to run a single replicate
# ============================================================================
run_single_replicate <- function(i.rep, data_full, true_patt, M, B, alpha) {
  
  # RETROSPECTIVE SAMPLING
  # Based on treatment status and covariates
  c0 <- log(0.005 / (1 - 0.005))
  c1 <- log(1.05)
  c2 <- log(1.10)
  c3 <- log(1.15)
  c4 <- log(1.10)
  c5 <- log(1.05)
  c6 <- log(1.10)
  delta_z_in_s <- log(0.9)
  
  # Calculate retrospective sampling probabilities
  formula_S <- c0 + delta_z_in_s * data_full$z + c1 * data_full$x1 + c2 * data_full$x2 +
    c3 * data_full$x3 + c4 * data_full$x4 + c5 * data_full$x5 + c6 * data_full$x6
  
  prob_S <- expit(formula_S)
  data_full$Prob <- prob_S
  
  # Scale to get expected sample size ~5000
  expected_n <- sum(prob_S)
  scaling_factor <- 5000 / expected_n
  prob_S_scaled <- pmin(prob_S * scaling_factor, 1)
  
  # Draw retrospective sample
  data_full$S <- rbinom(nrow(data_full), 1, prob_S_scaled)
  sample <- data_full[data_full$S == 1, ]
  
      # Add retrospective sampling weights (inverse probability weights)
    sample$weights_raw <- 1 / sample$Prob
    
    # Create normalized weights for PS Full (Survey-Weighted)
    # Normalization: w × length(w)/sum(w)
    sample$weights_normalized <- sample$weights_raw * length(sample$weights_raw) / sum(sample$weights_raw)
    
    # For compatibility, create weights column (normalized for PS Full)
    sample$weights <- sample$weights_normalized
    
    # Extract variables
    Y <- sample$y
    X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
    A <- sample$z
    w <- sample$weights_normalized  # Normalized weights for PS Full
    w_raw <- sample$weights_raw     # Raw weights for WDSM
  
  # Store sample size info
  n_sample <- nrow(sample)
  n_treated <- sum(A == 1)
  n_control <- sum(A == 0)
  
  # Initialize results for this replicate
  replicate_results <- list(
    n_sample = n_sample,
    n_treated = n_treated,
    n_control = n_control
  )
  
  # Check if we have enough units for matching
  if (n_treated < 10 || n_control < M * 2) {
    warning(paste("Replicate", i.rep, "has too few units for matching"))
    return(replicate_results)
  }
  
      # ============================================================
    # METHOD 1: UNWEIGHTED DOUBLE SCORE MATCHING (dsmatch-master)
    # ============================================================
    tryCatch({
      # Create interaction term for consistency
      X_dsm <- cbind(X, X[,1] * X[,2])
      colnames(X_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      
      # Run DSM for ATT with bootstrap
      dsm_result <- dsmatchATT(
        Y = Y,
        X = X_dsm,
        A = A,
        method = "dsm",
        model.ps = "logit",    # Use GLM logit for propensity score
        # lp.ps not needed with "logit"
        model.pg = "linpred",  # Keep linear predictors for outcome
        lp.pg = X_dsm,         # All covariates including interaction
        cov.balance = FALSE,
        varest = TRUE,
        boots = B,
        mc = FALSE,
        ncpus = 1
      )
    
    replicate_results$dsm_unweighted <- list(
      estimate = dsm_result$est.ds,
      se = sqrt(dsm_result$bootvar[1,1]),
      ci_lower = dsm_result$est.ds - qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1]),
      ci_upper = dsm_result$est.ds + qnorm(1 - alpha/2) * sqrt(dsm_result$bootvar[1,1])
    )
    
  }, error = function(e) {
    cat("DSM Unweighted Error in replicate", i.rep, ":", e$message, "\n")
    replicate_results$dsm_unweighted <- list(
      estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
    )
  })
  
      # ============================================================
    # METHOD 2: UNWEIGHTED PROPENSITY SCORE MATCHING (dsmatch-master)
    # ============================================================
    tryCatch({
      # Create interaction term for consistency
      X_ps <- cbind(X, X[,1] * X[,2])
      colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
      
      # Run PS matching for ATT with bootstrap
      ps_result <- dsmatchATT(
        Y = Y,
        X = X_ps,
        A = A,
        method = "ps",
        model.ps = "logit",    # Use GLM logit for propensity score
        # lp.ps not needed with "logit"
        cov.balance = FALSE,
        varest = TRUE,
        boots = B,
        mc = FALSE,
        ncpus = 1
      )
    
    replicate_results$ps_unweighted <- list(
      estimate = ps_result$est.ps,
      se = sqrt(ps_result$bootvar[1,1]),
      ci_lower = ps_result$est.ps - qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1]),
      ci_upper = ps_result$est.ps + qnorm(1 - alpha/2) * sqrt(ps_result$bootvar[1,1])
    )
    
  }, error = function(e) {
    cat("PS Unweighted Error in replicate", i.rep, ":", e$message, "\n")
    replicate_results$ps_unweighted <- list(
      estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
    )
  })
  
  # ============================================================
  # METHOD 3: UNWEIGHTED PROGNOSTIC SCORE MATCHING (dsmatch-master)
  # ============================================================
  tryCatch({
    # Create interaction term for consistency
    X_pg <- cbind(X, X[,1] * X[,2])
    colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
    
    # Run PG matching for ATT with bootstrap
    pg_result <- dsmatchATT(
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
    
    replicate_results$pg_unweighted <- list(
      estimate = pg_result$est.pg,
      se = sqrt(pg_result$bootvar[1,1]),
      ci_lower = pg_result$est.pg - qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1]),
      ci_upper = pg_result$est.pg + qnorm(1 - alpha/2) * sqrt(pg_result$bootvar[1,1])
    )
    
  }, error = function(e) {
    cat("PG Unweighted Error in replicate", i.rep, ":", e$message, "\n")
    replicate_results$pg_unweighted <- list(
      estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
    )
  })
  
  # ============================================================
  # METHOD 4: SURVEY-WEIGHTED PROPENSITY SCORE MATCHING (MatchIt)
  # Using FULL MATCHING with retrospective sampling weights
  # ============================================================
  tryCatch({
    # Create data frame with weights
    match_data_sw <- data.frame(
      Y = Y,
      A = A,
      x1 = X[,1],
      x2 = X[,2],
      x3 = X[,3],
      x4 = X[,4],
      x5 = X[,5],
      x6 = X[,6],
      sw = w
    )
    
    # Full matching with retrospective sampling weights
    m_ps_sw <- matchit(
      A ~ x1 + x2 + x3 + x4 + x5 + x6 + x1:x2,
      data = match_data_sw,
      method = "full",         # Full matching
      distance = "glm",        # Standard GLM for propensity score
      link = "logit",
      s.weights = ~ sw,        # Include retrospective sampling weights
      estimand = "ATT"
    )
    
    # Extract matched data with combined weights
    md_sw <- match_data(m_ps_sw)
    
    # Fit outcome model with combined weights
    fit_sw <- lm(Y ~ A * (x1 + x2 + x3 + x4 + x5 + x6 + x1:x2), 
                 data = md_sw,
                 weights = weights)  # Combined matching * survey weights
    
    # Use marginaleffects to compute marginal ATT
    att_result <- avg_comparisons(
      fit_sw,
      variables = "A",
      vcov = ~subclass,
      newdata = subset(md_sw, A == 1),  # ATT: average over treated units
      wts = "sw"              # Retrospective sampling weights
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
      estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
    )
  })
  
  # ============================================================
  # METHOD 5: SURVEY-WEIGHTED DOUBLE SCORE MATCHING (Version 2 WDSM with Standard GLM/LM)
  # ============================================================
  tryCatch({
    # Use our Version 2 WDSM function with standard GLM/LM
    # NOTE: Using raw (unnormalized) weights for WDSM
          wdsm_result <- wdsm_patt_v2_standard(
      Y = Y,
      X = X,
      A = A,
      weights = w_raw,  # Use raw weights for WDSM
      M = M,
      B = B,
      alpha = alpha,
      show_progress = FALSE,
      exponential_bootstrap = FALSE  # Use multinomial bootstrap
    )
    
    replicate_results$dsm_weighted <- list(
      estimate = wdsm_result$point_estimate,
      se = wdsm_result$standard_error,
      ci_lower = wdsm_result$ci_normal[1],
      ci_upper = wdsm_result$ci_normal[2]
    )
    
  }, error = function(e) {
    cat("WDSM V2 Error in replicate", i.rep, ":", e$message, "\n")
    replicate_results$dsm_weighted <- list(
      estimate = NA, se = NA, ci_lower = NA, ci_upper = NA
    )
  })
  
  return(replicate_results)
}

# ============================================================================
# Load Population Data
# ============================================================================
cat("Loading super population data...\n")
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_full <- SuperPopGen_GoodOverlap_AllinOne_0118_2025[[1]]  # Use first scenario

# Parameters
n_reps <- 10     # Number of simulation replicates (QUICK TEST)
M <- 5           # Number of matches per unit
B <- 200         # Bootstrap iterations
alpha <- 0.05    # Significance level

# Calculate true population PATT
true_patt <- mean(data_full$y1[data_full$z == 1]) - mean(data_full$y0[data_full$z == 1])

# ============================================================================
# Main Simulation Loop
# ============================================================================
cat("\n============================================================\n")
cat("COMPREHENSIVE COMPARISON - PATT RETROSPECTIVE SAMPLING\n")
cat("============================================================\n")
cat(sprintf("\nTrue Population PATT: %.4f\n", true_patt))
cat(sprintf("Running %d replicates with M=%d, B=%d\n", n_reps, M, B))
cat("Methods being compared:\n")
cat("1. Unweighted DSM (dsmatch-master)\n")
cat("2. Unweighted PS matching (dsmatch-master)\n")
cat("3. Unweighted PG matching (dsmatch-master)\n")
cat("4. Survey-weighted PS full matching (MatchIt)\n")
cat("5. Survey-weighted DSM V2 with standard GLM/LM (wdsm_patt_v2_standard)\n")

start_time <- Sys.time()

# Run replicates in parallel
all_results <- foreach(i.rep = 1:n_reps,
                      .packages = c("MASS", "MatchIt", "marginaleffects", "boot"),
                      .export = c("dsmatchATT", "wdsm_patt_v2_standard", 
                                 "run_single_replicate", "match_data",
                                 "avg_comparisons", "expit")) %dopar% {
                                   
  # Set random seed for this replicate
  set.seed(20250128 + i.rep)
  
  # Run single replicate
  result <- run_single_replicate(i.rep, data_full, true_patt, M, B, alpha)
  
  # Print progress
  if (i.rep %% 5 == 0) {
    cat(sprintf("Completed replicate %d\n", i.rep))
  }
  
  return(result)
}

# Clean up parallel cluster
stopCluster(cl)

end_time <- Sys.time()
cat(sprintf("\nTotal runtime: %.2f minutes\n", 
            as.numeric(difftime(end_time, start_time, units = "mins"))))

# ============================================================================
# Analyze Results
# ============================================================================
cat("\n============================================================\n")
cat("RESULTS SUMMARY - PATT RETROSPECTIVE SAMPLING\n")
cat("============================================================\n")

# Extract results for analysis
methods <- c("dsm_unweighted", "ps_unweighted", "pg_unweighted", 
             "ps_weighted", "dsm_weighted")
method_names <- c("DSM (Unweighted)", "PS (Unweighted)", "PG (Unweighted)", 
                                     "PS Full (Weighted)", "WDSM V2 Standard GLM/LM (Weighted)")

# Initialize summary statistics
summary_stats <- data.frame(
  Method = method_names,
  Mean_Estimate = numeric(length(methods)),
  Bias = numeric(length(methods)),
  Relative_Bias = numeric(length(methods)),
  Empirical_SE = numeric(length(methods)),
  Mean_Est_SE = numeric(length(methods)),
  SE_Ratio = numeric(length(methods)),
  RMSE = numeric(length(methods)),
  Coverage = numeric(length(methods)),
  Mean_CI_Width = numeric(length(methods)),
  N_Failed = numeric(length(methods))
)

# Calculate summary statistics
for (i in seq_along(methods)) {
  method <- methods[i]
  
  # Extract estimates, SEs, and CIs across all replicates
  estimates <- sapply(all_results, function(x) x[[method]]$estimate)
  ses <- sapply(all_results, function(x) x[[method]]$se)
  ci_lowers <- sapply(all_results, function(x) x[[method]]$ci_lower)
  ci_uppers <- sapply(all_results, function(x) x[[method]]$ci_upper)
  
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
    # Mean estimate
    summary_stats$Mean_Estimate[i] <- mean(estimates)
    
    # Bias
    summary_stats$Bias[i] <- mean(estimates) - true_patt
    
    # Relative bias (percentage)
    summary_stats$Relative_Bias[i] <- 100 * (mean(estimates) - true_patt) / true_patt
    
    # Empirical SE
    summary_stats$Empirical_SE[i] <- sd(estimates)
    
    # Mean estimated SE
    summary_stats$Mean_Est_SE[i] <- mean(ses)
    
    # SE ratio
    summary_stats$SE_Ratio[i] <- mean(ses) / sd(estimates)
    
    # RMSE
    summary_stats$RMSE[i] <- sqrt(mean((estimates - true_patt)^2))
    
    # Coverage
    coverage <- mean(ci_lowers <= true_patt & ci_uppers >= true_patt)
    summary_stats$Coverage[i] <- coverage
    
    # Mean CI width
    summary_stats$Mean_CI_Width[i] <- mean(ci_uppers - ci_lowers)
  }
}

# Print summary table
cat(sprintf("\nTrue PATT: %.4f\n\n", true_patt))
print(summary_stats[, c("Method", "Mean_Estimate", "Bias", "Relative_Bias", 
                        "Empirical_SE", "Mean_Est_SE", "SE_Ratio", "RMSE", 
                        "Coverage", "Mean_CI_Width", "N_Failed")], digits = 4)

# Calculate variance-based relative efficiency (using unweighted PS as reference)
# First, build matrix of estimates across all replicates
est_mat <- sapply(methods, function(m) 
                  sapply(all_results, function(res) res[[m]]$estimate))

# Remove rows with any NAs to ensure fair comparison
good_rows <- apply(!is.na(est_mat), 1, all)
est_mat_clean <- est_mat[good_rows, , drop = FALSE]
cat(sprintf("\nUsing %d complete replicates (out of %d) for variance calculation\n", 
            nrow(est_mat_clean), length(all_results)))

# Compute empirical (Monte Carlo) variances
emp_var <- apply(est_mat_clean, 2, var)
names(emp_var) <- methods

# Variance-based relative efficiency (using PS unweighted as reference)
ref_method <- "ps_unweighted"  # index 2
rel_eff_var <- emp_var[ref_method] / emp_var

# Add variance-based relative efficiency to summary
summary_stats$RelEff_Var <- rel_eff_var

# Also keep RMSE-based relative efficiency for comparison
ps_unweighted_rmse <- summary_stats$RMSE[2]
rel_eff_rmse <- ps_unweighted_rmse / summary_stats$RMSE
summary_stats$RelEff_RMSE <- rel_eff_rmse

# Add empirical variance to summary
summary_stats$Emp_Var <- emp_var

# Print variance-based relative efficiency
cat("\n\nVariance-Based Relative Efficiency Analysis:\n")
cat("============================================\n")
cat("Reference method: PS (Unweighted)\n\n")

variance_table <- data.frame(
  Method = method_names,
  Empirical_Variance = sprintf("%.5f", emp_var),
  Relative_Efficiency = sprintf("%.2f", rel_eff_var),
  Interpretation = ifelse(rel_eff_var > 1, 
                         sprintf("%.0f%% less variance", (rel_eff_var - 1) * 100),
                         sprintf("%.0f%% more variance", (1 - rel_eff_var) * 100))
)
print(variance_table, row.names = FALSE)

# Save results
save(all_results, summary_stats, true_patt, 
     file = "comprehensive_patt_retrospective_results.RData")
cat("\nResults saved to 'comprehensive_patt_retrospective_results.RData'\n")

# ============================================================================
# Create detailed results table
# ============================================================================
detailed_results <- data.frame(
  Method = summary_stats$Method,
  Estimate = sprintf("%.4f", summary_stats$Mean_Estimate),
  Bias = sprintf("%.4f (%.1f%%)", summary_stats$Bias, summary_stats$Relative_Bias),
  Emp_SE = sprintf("%.4f", summary_stats$Empirical_SE),
  Est_SE = sprintf("%.4f", summary_stats$Mean_Est_SE),
  SE_Ratio = sprintf("%.3f", summary_stats$SE_Ratio),
  RMSE = sprintf("%.4f", summary_stats$RMSE),
  Coverage = sprintf("%.1f%%", summary_stats$Coverage * 100),
  CI_Width = sprintf("%.4f", summary_stats$Mean_CI_Width),
  RelEff_Var = sprintf("%.2f", summary_stats$RelEff_Var),
  Failed = sprintf("%d/%d", summary_stats$N_Failed, n_reps)
)

cat("\n\nDetailed Results Table:\n")
cat("========================\n")
print(detailed_results, row.names = FALSE)

# Save detailed results
write.csv(detailed_results, "comprehensive_patt_retrospective_table.csv", row.names = FALSE)
cat("\nDetailed results saved to 'comprehensive_patt_retrospective_table.csv'\n")

# ============================================================================
# Create visualization
# ============================================================================
library(ggplot2)
library(tidyr)
library(dplyr)

# Prepare data for plotting key metrics
plot_data <- summary_stats %>%
  select(Method, Relative_Bias, SE_Ratio, Coverage, RelEff_Var) %>%
  pivot_longer(cols = c(Relative_Bias, SE_Ratio, Coverage, RelEff_Var),
               names_to = "Metric",
               values_to = "Value")

# Rename metrics for better labels
plot_data$Metric <- factor(plot_data$Metric,
                          levels = c("Relative_Bias", "SE_Ratio", "Coverage", "RelEff_Var"),
                          labels = c("Relative Bias (%)", "SE Ratio", "Coverage", "Relative Efficiency (Var)"))

# Create comparison plot
p <- ggplot(plot_data, aes(x = Method, y = Value, fill = Method)) +
  geom_bar(stat = "identity") +
  facet_wrap(~Metric, scales = "free_y", nrow = 2) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    legend.position = "none",
    strip.text = element_text(face = "bold", size = 12),
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5)
  ) +
  labs(
    title = "Comparison of Matching Methods for PATT: Retrospective Sampling",
    subtitle = sprintf("True PATT = %.4f | N replicates = %d | M = %d | B = %d", 
                       true_patt, n_reps, M, B),
    y = "",
    x = ""
  ) +
  scale_fill_manual(values = c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00"))

# Add reference lines
p <- p + 
  geom_hline(data = filter(plot_data, Metric == "Coverage"),
             aes(yintercept = 0.95), linetype = "dashed", color = "red") +
  geom_hline(data = filter(plot_data, Metric == "Relative Bias (%)"),
             aes(yintercept = 0), linetype = "dashed", color = "red") +
  geom_hline(data = filter(plot_data, Metric == "SE Ratio"),
             aes(yintercept = 1), linetype = "dashed", color = "red") +
  geom_hline(data = filter(plot_data, Metric == "Relative Efficiency (Var)"),
             aes(yintercept = 1), linetype = "dashed", color = "red")

# Save plot
ggsave("comprehensive_patt_retrospective_plot.pdf", p, width = 12, height = 8)
cat("\nPlot saved to 'comprehensive_patt_retrospective_plot.pdf'\n")

# ============================================================================
# Create boxplot for estimates
# ============================================================================
# Prepare data for boxplot
boxplot_data <- data.frame()
for (i in seq_along(methods)) {
  method <- methods[i]
  estimates <- sapply(all_results, function(x) x[[method]]$estimate)
  valid <- !is.na(estimates)
  estimates <- estimates[valid]
  
  if (length(estimates) > 0) {
    temp_df <- data.frame(
      Method = method_names[i],
      Estimate = estimates
    )
    boxplot_data <- rbind(boxplot_data, temp_df)
  }
}

# Create boxplot
p_box <- ggplot(boxplot_data, aes(x = Method, y = Estimate, fill = Method)) +
  geom_boxplot(alpha = 0.7) +
  geom_hline(yintercept = true_patt, color = "red", linetype = "dashed", size = 1) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none",
    plot.title = element_text(hjust = 0.5, face = "bold")
  ) +
  labs(
    title = "Distribution of PATT Estimates: Retrospective Sampling",
    subtitle = sprintf("True PATT = %.4f (red dashed line)", true_patt),
    y = "PATT Estimate",
    x = "Method"
  ) +
  scale_fill_manual(values = c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00")) +
  coord_cartesian(ylim = c(true_patt - 0.3, true_patt + 0.3))

# Save boxplot
ggsave("comprehensive_patt_retrospective_boxplot.pdf", p_box, width = 10, height = 6)
cat("\nBoxplot saved to 'comprehensive_patt_retrospective_boxplot.pdf'\n")

# ============================================================================
# Additional diagnostics
# ============================================================================
cat("\n\nDiagnostic Summary:\n")
cat("==================\n")

# Sample size information
sample_sizes <- sapply(all_results, function(x) x$n_sample)
n_treated <- sapply(all_results, function(x) x$n_treated)
n_control <- sapply(all_results, function(x) x$n_control)

cat(sprintf("Average sample size: %.1f (range: %d-%d)\n", 
            mean(sample_sizes), min(sample_sizes), max(sample_sizes)))
cat(sprintf("Average treated units: %.1f (range: %d-%d)\n", 
            mean(n_treated), min(n_treated), max(n_treated)))
cat(sprintf("Average control units: %.1f (range: %d-%d)\n", 
            mean(n_control), min(n_control), max(n_control)))
cat(sprintf("Treatment proportion: %.1f%%\n", 100 * mean(n_treated) / mean(sample_sizes)))

# Winner analysis
cat("\n\nPerformance Summary:\n")
cat("===================\n")
cat(sprintf("Lowest bias: %s (%.4f)\n", 
            summary_stats$Method[which.min(abs(summary_stats$Bias))],
            summary_stats$Bias[which.min(abs(summary_stats$Bias))]))
cat(sprintf("Best coverage: %s (%.1f%%)\n", 
            summary_stats$Method[which.max(summary_stats$Coverage)],
            100 * max(summary_stats$Coverage)))
cat(sprintf("Best SE ratio: %s (%.3f)\n", 
            summary_stats$Method[which.min(abs(summary_stats$SE_Ratio - 1))],
            summary_stats$SE_Ratio[which.min(abs(summary_stats$SE_Ratio - 1))]))
cat(sprintf("Lowest RMSE: %s (%.4f)\n", 
            summary_stats$Method[which.min(summary_stats$RMSE)],
            min(summary_stats$RMSE)))
cat(sprintf("Best variance efficiency vs PS (Unweighted): %s (%.2fx)\n", 
            summary_stats$Method[which.max(summary_stats$RelEff_Var)],
            max(summary_stats$RelEff_Var)))

# Report computation time
cat(sprintf("\nTotal computation time: %.2f minutes\n", 
            as.numeric(difftime(end_time, start_time, units = "mins"))))
cat(sprintf("Average time per replicate: %.2f seconds\n", 
            as.numeric(difftime(end_time, start_time, units = "secs")) / n_reps))

cat("\n============================================================\n")
cat("PATT RETROSPECTIVE COMPARISON COMPLETED\n")
cat("============================================================\n")