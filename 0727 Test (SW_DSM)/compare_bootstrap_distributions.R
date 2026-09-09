##############################################################################
# Compare Bootstrap Distributions from Both CI Methods
##############################################################################

library(ggplot2)
library(dplyr)
library(tidyr)

# Set seed for reproducibility
set.seed(2025)

# Load population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_GoodOverlap_AllinOne_0118_2025
pop_data <- data_sets[[1]]
pop_data$ones <- 1
pop_data$id <- 1:nrow(pop_data)

# Rename columns
names(pop_data)[names(pop_data) == "z"] <- "A"
names(pop_data)[names(pop_data) == "y"] <- "Y"
names(pop_data)[names(pop_data) == "y0"] <- "Y0"
names(pop_data)[names(pop_data) == "y1"] <- "Y1"
for (i in 1:6) {
  names(pop_data)[names(pop_data) == paste0("x", i)] <- paste0("X", i)
}

# Source necessary functions
source("wdsm_ci_functions.R")

# Generate one sample for detailed analysis
cat("Generating sample for detailed bootstrap analysis...\n")
sample_data <- retrospective_sample(pop_data, n_sample = 1000)

# Run both methods with more bootstrap iterations
B_detailed <- 200  # More iterations for distribution comparison
M <- 3

cat("\nRunning Method 1 with B =", B_detailed, "iterations...\n")
result1 <- method1_bootstrap_ci(sample_data, M = M, B = B_detailed)

cat("\nRunning Method 2 with B =", B_detailed, "iterations...\n")
result2 <- method2_bootstrap_ci(sample_data, M = M, B = B_detailed)

# Combine bootstrap distributions
boot_dist <- data.frame(
  tau_boot = c(result1$tau_boot, result2$tau_boot),
  method = rep(c("Exponential Bootstrap", "Survey Bootstrap"), 
               each = B_detailed)
)

# Summary statistics
cat("\n=== BOOTSTRAP DISTRIBUTION COMPARISON ===\n")
boot_summary <- boot_dist %>%
  group_by(method) %>%
  summarise(
    mean = mean(tau_boot),
    sd = sd(tau_boot),
    median = median(tau_boot),
    q025 = quantile(tau_boot, 0.025),
    q975 = quantile(tau_boot, 0.975),
    skewness = (mean(tau_boot) - median(tau_boot)) / sd(tau_boot),
    .groups = 'drop'
  )

print(boot_summary)

# Visualizations
cat("\nCreating visualizations...\n")

# 1. Density plots
p1 <- ggplot(boot_dist, aes(x = tau_boot, fill = method)) +
  geom_density(alpha = 0.5) +
  geom_vline(xintercept = result1$tau_hat, linetype = "dashed") +
  labs(title = "Bootstrap Distributions Comparison",
       subtitle = sprintf("Point estimate = %.4f (dashed line)", result1$tau_hat),
       x = "Bootstrap PATE Estimate", y = "Density") +
  theme_minimal() +
  scale_fill_brewer(palette = "Set1")

# 2. Box plots
p2 <- ggplot(boot_dist, aes(x = method, y = tau_boot, fill = method)) +
  geom_boxplot(alpha = 0.7) +
  geom_hline(yintercept = result1$tau_hat, linetype = "dashed") +
  labs(title = "Bootstrap Distribution Box Plots",
       subtitle = sprintf("Point estimate = %.4f (dashed line)", result1$tau_hat),
       x = "Method", y = "Bootstrap PATE Estimate") +
  theme_minimal() +
  theme(legend.position = "none")

# 3. Q-Q plot to compare distributions
boot_wide <- boot_dist %>%
  group_by(method) %>%
  mutate(row = row_number()) %>%
  pivot_wider(names_from = method, values_from = tau_boot) %>%
  na.omit()

p3 <- ggplot(boot_wide, aes(x = `Exponential Bootstrap`, y = `Survey Bootstrap`)) +
  geom_point(alpha = 0.5) +
  geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
  labs(title = "Q-Q Plot: Exponential vs Survey Bootstrap",
       subtitle = "Red line indicates perfect agreement",
       x = "Exponential Bootstrap Quantiles",
       y = "Survey Bootstrap Quantiles") +
  theme_minimal()

# 4. Cumulative distribution functions
p4 <- ggplot(boot_dist, aes(x = tau_boot, color = method)) +
  stat_ecdf(size = 1) +
  labs(title = "Empirical CDFs of Bootstrap Distributions",
       x = "Bootstrap PATE Estimate", y = "Cumulative Probability") +
  theme_minimal() +
  scale_color_brewer(palette = "Set1")

# Save plots
pdf("bootstrap_distributions_comparison.pdf", width = 12, height = 10)
print(p1)
print(p2)
print(p3)
print(p4)
dev.off()

cat("\nPlots saved to: bootstrap_distributions_comparison.pdf\n")

# Statistical tests
cat("\n=== STATISTICAL TESTS ===\n")

# Kolmogorov-Smirnov test
ks_test <- ks.test(
  boot_dist$tau_boot[boot_dist$method == "Exponential Bootstrap"],
  boot_dist$tau_boot[boot_dist$method == "Survey Bootstrap"]
)
cat(sprintf("\nKolmogorov-Smirnov test p-value: %.4f\n", ks_test$p.value))
if (ks_test$p.value > 0.05) {
  cat("The two bootstrap distributions are not significantly different (p > 0.05)\n")
} else {
  cat("The two bootstrap distributions are significantly different (p < 0.05)\n")
}

# Variance ratio test
var_ratio <- var(result1$tau_boot) / var(result2$tau_boot)
cat(sprintf("\nVariance ratio (Method 1 / Method 2): %.4f\n", var_ratio))

# Save detailed results
save(result1, result2, boot_dist, boot_summary, 
     file = "bootstrap_distributions_detailed.RData")
cat("\nDetailed results saved to: bootstrap_distributions_detailed.RData\n") 