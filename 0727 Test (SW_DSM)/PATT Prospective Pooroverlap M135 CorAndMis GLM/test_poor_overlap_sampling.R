# Test script to understand poor overlap sampling issue
library(sampling)
set.seed(123)

# Load data
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
data <- SuperPopGen_PoorOverlap_AllinOne_0118_2025[[1]]

# Multi-stage sampling (same as in main script)
size1 <- rep(100000, 10)  # Population size per stratum
size2 <- rep(5, 10)       # Number of clusters per stratum
size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
           rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
           rep(250/5, 5), rep(150/5, 5))  # Cluster-level sample sizes

# Add required columns for sampling
data$ones <- 1
data$id <- seq_len(nrow(data))

# Perform sampling
s <- mstage(data, stage = list("stratified", "cluster", ""), 
            varnames = list("Strata", "Cluster", "ones"), 
            size = list(size1, size2, size3), 
            method = list("", "srswor", "srswor"))

sample <- getdata(data, s)[[3]]  # Extract the final sample

# Analyze the sample
cat("Sample size:", nrow(sample), "\n")
cat("Treated units:", sum(sample$z == 1), "\n")
cat("Control units:", sum(sample$z == 0), "\n\n")

# Check PS distribution in sample
ps_control_sample <- sample$prob_treat[sample$z == 0]
ps_treated_sample <- sample$prob_treat[sample$z == 1]

cat("Sample PS ranges:\n")
cat("Control PS range:", range(ps_control_sample), "\n")
cat("Treated PS range:", range(ps_treated_sample), "\n\n")

# Check overlap
cat("Overlap in sample:\n")
cat("Control units with PS > 0.1:", sum(ps_control_sample > 0.1), "\n")
cat("Treated units with PS < 0.9:", sum(ps_treated_sample < 0.9), "\n")

# Check if there's any common support
common_min <- max(min(ps_treated_sample), min(ps_control_sample))
common_max <- min(max(ps_treated_sample), max(ps_control_sample))
cat("\nCommon support region: [", common_min, ",", common_max, "]\n")

if (common_min >= common_max) {
  cat("NO COMMON SUPPORT - Matching will fail!\n")
} else {
  controls_in_common <- sum(ps_control_sample >= common_min & ps_control_sample <= common_max)
  treated_in_common <- sum(ps_treated_sample >= common_min & ps_treated_sample <= common_max)
  cat("Controls in common support:", controls_in_common, "\n")
  cat("Treated in common support:", treated_in_common, "\n")
}
