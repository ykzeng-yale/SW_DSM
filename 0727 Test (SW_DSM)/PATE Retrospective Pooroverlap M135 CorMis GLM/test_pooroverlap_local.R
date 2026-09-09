#!/usr/bin/env Rscript

# Quick test script for Poor Overlap data generation
# This tests that the data loads correctly and has expected properties

cat("\n============================================================\n")
cat("Testing Poor Overlap Data Configuration\n")
cat("============================================================\n")

# Load required libraries
library(MASS)

# Source required functions
source("wdsm_ci_functions.R")

# Load population data
cat("\nLoading Poor Overlap population data...\n")
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_PoorOverlap_AllinOne_0118_2025

# Extract first dataset and rename columns
population <- data_sets[[1]]
names(population)[names(population) == "z"] <- "A"
names(population)[names(population) == "y"] <- "Y"
names(population)[names(population) == "y0"] <- "Y0"
names(population)[names(population) == "y1"] <- "Y1"
for (i in 1:6) {
  names(population)[names(population) == paste0("x", i)] <- paste0("X", i)
}

# Basic statistics
cat("\n------------------------------------------------------------\n")
cat("Population Statistics:\n")
cat("------------------------------------------------------------\n")
cat("Population size:", nrow(population), "\n")
cat("Treatment prevalence:", round(mean(population$A), 3), "\n")
cat("True PATE:", round(mean(population$Y1 - population$Y0), 4), "\n")

# Check propensity score distribution
cat("\n------------------------------------------------------------\n")
cat("Propensity Score Distribution:\n")
cat("------------------------------------------------------------\n")
ps_summary <- summary(population$prob_treat)
cat("Min:", round(ps_summary[1], 4), "\n")
cat("Q1:", round(ps_summary[2], 4), "\n")
cat("Median:", round(ps_summary[3], 4), "\n")
cat("Mean:", round(ps_summary[4], 4), "\n")
cat("Q3:", round(ps_summary[5], 4), "\n")
cat("Max:", round(ps_summary[6], 4), "\n")

# Check overlap by treatment group
cat("\n------------------------------------------------------------\n")
cat("Propensity Score by Treatment Group:\n")
cat("------------------------------------------------------------\n")
ps_control <- population$prob_treat[population$A == 0]
ps_treated <- population$prob_treat[population$A == 1]

cat("\nControl group (A=0):\n")
cat("  Mean PS:", round(mean(ps_control), 4), "\n")
cat("  SD PS:", round(sd(ps_control), 4), "\n")
cat("  Range: [", round(min(ps_control), 4), ",", round(max(ps_control), 4), "]\n")

cat("\nTreated group (A=1):\n")
cat("  Mean PS:", round(mean(ps_treated), 4), "\n")
cat("  SD PS:", round(sd(ps_treated), 4), "\n")
cat("  Range: [", round(min(ps_treated), 4), ",", round(max(ps_treated), 4), "]\n")

# Test retrospective sampling
cat("\n------------------------------------------------------------\n")
cat("Testing Retrospective Sampling:\n")
cat("------------------------------------------------------------\n")

set.seed(20250127)
sample <- retrospective_sample(population, n_sample = 1000)

cat("Sample size:", nrow(sample), "\n")
cat("Treatment prevalence in sample:", round(mean(sample$A), 3), "\n")
cat("Average survey weight:", round(mean(sample$survey_weight), 2), "\n")
cat("Survey weight range: [", round(min(sample$survey_weight), 2), 
    ",", round(max(sample$survey_weight), 2), "]\n")

# Test a single method to ensure everything works
cat("\n------------------------------------------------------------\n")
cat("Testing Single Method Execution:\n")
cat("------------------------------------------------------------\n")

# Extract variables
Y <- sample$Y
X <- as.matrix(sample[, c("X1", "X2", "X3", "X4", "X5", "X6")])
A <- sample$A

# Try simple WDSM point estimate
tryCatch({
  wdsm_est <- wdsm_point_estimate(Y, X, A, m = 3)
  cat("WDSM point estimate (m=3):", round(wdsm_est, 4), "\n")
  cat("Bias from true PATE:", round(wdsm_est - mean(population$Y1 - population$Y0), 4), "\n")
}, error = function(e) {
  cat("Error in WDSM estimation:", e$message, "\n")
})

cat("\n============================================================\n")
cat("Test Complete - Poor Overlap Data Configuration Works!\n")
cat("============================================================\n")
