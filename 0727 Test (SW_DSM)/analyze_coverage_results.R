#!/usr/bin/env Rscript

# Script to analyze WDSM coverage simulation results

# Check which results file to analyze
if (file.exists("wdsm_coverage_medium_results.RData")) {
  cat("Analyzing medium simulation results...\n")
  load("wdsm_coverage_medium_results.RData")
} else if (file.exists("wdsm_coverage_simulation_results.RData")) {
  cat("Analyzing full simulation results...\n")
  load("wdsm_coverage_simulation_results.RData")
} else {
  cat("No results file found. Run a simulation first.\n")
  quit(status = 1)
}

cat("\n=======================================================\n")
cat("WDSM COVERAGE SIMULATION - DETAILED ANALYSIS\n")
cat("=======================================================\n\n")

# Basic statistics
n_total <- nrow(simulation_results)
n_valid <- nrow(valid_results)
n_failed <- n_total - n_valid

cat("1. SIMULATION SUMMARY\n")
cat("-------------------\n")
cat("Total simulations attempted:", n_total, "\n")
cat("Successful simulations:", n_valid, "\n")
cat("Failed simulations:", n_failed, sprintf("(%.1f%%)\n", 100*n_failed/n_total))
cat("\n")

# Coverage analysis
cat("2. COVERAGE ANALYSIS\n")
cat("-------------------\n")
cat("Nominal coverage level: 95%\n")
cat("Empirical coverage:", sprintf("%.2f%%", coverage), "\n")

# Binomial test for coverage
binom_test <- binom.test(sum(valid_results$covers), n_valid, p = 0.95)
cat("\nExact binomial test:\n")
cat("- 95% CI for coverage: [", sprintf("%.2f%%", 100*binom_test$conf.int[1]), 
    ", ", sprintf("%.2f%%", 100*binom_test$conf.int[2]), "]\n", sep="")
cat("- p-value:", format.pval(binom_test$p.value), "\n")

# Monte Carlo standard error
mc_se <- sqrt(coverage * (100 - coverage) / n_valid)
cat("\nMonte Carlo standard error:", sprintf("%.2f%%", mc_se), "\n")
cat("Expected range (±2 SE): [", sprintf("%.2f%%", coverage - 2*mc_se), 
    ", ", sprintf("%.2f%%", coverage + 2*mc_se), "]\n", sep="")

# Estimation accuracy
cat("\n3. ESTIMATION ACCURACY\n")
cat("---------------------\n")
true_value <- valid_results$true_value[1]
estimates <- valid_results$estimate
bias <- mean(estimates - true_value)
rel_bias <- 100 * bias / true_value
mse <- mean((estimates - true_value)^2)
rmse <- sqrt(mse)

cat("True PATE:", round(true_value, 4), "\n")
cat("Average estimate:", round(mean(estimates), 4), "\n")
cat("Median estimate:", round(median(estimates), 4), "\n")
cat("Bias:", round(bias, 4), sprintf("(%.1f%%)\n", rel_bias))
cat("RMSE:", round(rmse, 4), "\n")

# Standard error analysis
cat("\n4. STANDARD ERROR ANALYSIS\n")
cat("-------------------------\n")
avg_se <- mean(valid_results$se)
empirical_sd <- sd(estimates)
se_ratio <- avg_se / empirical_sd

cat("Average estimated SE:", round(avg_se, 4), "\n")
cat("Empirical SD of estimates:", round(empirical_sd, 4), "\n")
cat("SE ratio (Est/Emp):", round(se_ratio, 3), "\n")
cat("Assessment:", ifelse(se_ratio > 1.1, "Conservative", 
                        ifelse(se_ratio < 0.9, "Anti-conservative", "Well-calibrated")), "\n")

# CI width analysis
cat("\n5. CONFIDENCE INTERVAL WIDTH\n")
cat("---------------------------\n")
ci_widths <- valid_results$ci_upper - valid_results$ci_lower
cat("Average CI width:", round(mean(ci_widths), 4), "\n")
cat("Median CI width:", round(median(ci_widths), 4), "\n")
cat("Width range: [", round(min(ci_widths), 4), ", ", round(max(ci_widths), 4), "]\n", sep="")

# Coverage by estimate quantiles
cat("\n6. COVERAGE BY ESTIMATE QUANTILES\n")
cat("---------------------------------\n")
est_quartiles <- cut(estimates, 
                    breaks = quantile(estimates, probs = seq(0, 1, 0.25)),
                    include.lowest = TRUE, 
                    labels = c("Q1 (Low)", "Q2", "Q3", "Q4 (High)"))
coverage_by_quartile <- tapply(valid_results$covers, est_quartiles, function(x) mean(x) * 100)
for (q in names(coverage_by_quartile)) {
  cat(q, ":", sprintf("%.1f%%", coverage_by_quartile[q]), "\n")
}

# Plots
if (interactive() || !is.null(getOption("device"))) {
  pdf("wdsm_coverage_simulation_plots.pdf", width = 10, height = 8)
  
  par(mfrow = c(2, 2))
  
  # 1. Histogram of estimates with true value
  hist(estimates, breaks = 30, main = "Distribution of WDSM Estimates",
       xlab = "Estimate", col = "lightblue", probability = TRUE)
  abline(v = true_value, col = "red", lwd = 2, lty = 2)
  abline(v = mean(estimates), col = "blue", lwd = 2)
  # Add normal curve
  x_seq <- seq(min(estimates), max(estimates), length.out = 100)
  lines(x_seq, dnorm(x_seq, mean = mean(estimates), sd = sd(estimates)), 
        col = "darkblue", lwd = 2)
  legend("topright", 
         legend = c("True PATE", "Mean Est.", "Normal"),
         col = c("red", "blue", "darkblue"), 
         lty = c(2, 1, 1), lwd = 2, cex = 0.8)
  
  # 2. Coverage probability over time
  cum_coverage <- cumsum(valid_results$covers) / seq_along(valid_results$covers)
  plot(cum_coverage * 100, type = "l", 
       main = "Cumulative Coverage Rate",
       xlab = "Simulation Number", ylab = "Coverage (%)",
       ylim = c(85, 100), lwd = 2)
  abline(h = 95, col = "red", lty = 2, lwd = 2)
  abline(h = c(93, 97), col = "orange", lty = 3)
  # Add confidence band
  n_seq <- seq_along(cum_coverage)
  se_seq <- sqrt(0.95 * 0.05 / n_seq)
  polygon(c(n_seq, rev(n_seq)), 
          c(100*(0.95 - 1.96*se_seq), rev(100*(0.95 + 1.96*se_seq))),
          col = rgb(1, 0, 0, 0.1), border = NA)
  
  # 3. QQ plot of estimates
  qqnorm(estimates, main = "Q-Q Plot of Estimates")
  qqline(estimates, col = "red", lwd = 2)
  
  # 4. SE vs absolute error
  abs_error <- abs(estimates - true_value)
  plot(valid_results$se, abs_error, 
       main = "Standard Error vs Absolute Error",
       xlab = "Estimated SE", ylab = "|Estimate - True|",
       pch = 16, col = rgb(0, 0, 1, 0.5))
  abline(0, 1.96, col = "red", lty = 2, lwd = 2)  # 95% CI boundary
  abline(lm(abs_error ~ valid_results$se), col = "blue", lwd = 2)
  
  par(mfrow = c(1, 1))
  
  dev.off()
  cat("\nPlots saved to: wdsm_coverage_simulation_plots.pdf\n")
}

# Final assessment
cat("\n=======================================================\n")
cat("FINAL ASSESSMENT\n")
cat("=======================================================\n")

if (coverage >= 93 && coverage <= 97) {
  cat("✓ EXCELLENT: Coverage is within acceptable range of nominal level\n")
} else if (coverage >= 90 && coverage <= 99) {
  cat("⚠ ACCEPTABLE: Coverage deviates slightly from nominal level\n")
} else {
  cat("✗ POOR: Coverage significantly deviates from nominal level\n")
}

if (abs(rel_bias) <= 5) {
  cat("✓ Low bias: Estimates are well-centered\n")
} else if (abs(rel_bias) <= 10) {
  cat("⚠ Moderate bias: Some systematic deviation\n")
} else {
  cat("✗ High bias: Significant systematic error\n")
}

if (se_ratio >= 0.9 && se_ratio <= 1.1) {
  cat("✓ Well-calibrated standard errors\n")
} else {
  cat("⚠ Standard errors need calibration\n")
}

cat("\n") 