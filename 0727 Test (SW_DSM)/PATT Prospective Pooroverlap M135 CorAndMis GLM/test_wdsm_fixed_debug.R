#!/usr/bin/env Rscript
# Debug script for WDSM V1 Fixed

# Load libraries
library(survey)
library(sampling)
library(MASS)
library(mgcv)
library(glmnet)

# Set seed
set.seed(20250115)

# Source the fixed WDSM function
source("WDSM/R/wdsm_patt_prospective_v1_fixed.R")

# Load population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data <- SuperPopGen_GoodOverlap_AllinOne_0118_2025[[1]]

# Calculate true PATT
true_patt <- mean(data$y1[data$z == 1]) - mean(data$y0[data$z == 1])
cat("True PATT:", true_patt, "\n")

# Multi-stage sampling (same as in comparison script)
size1 <- rep(100000, 10)
size2 <- rep(5, 10)
size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
           rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
           rep(250/5, 5), rep(150/5, 5))

# Add required columns
data$ones <- 1
data$id <- seq_len(nrow(data))

# Draw sample
s <- mstage(data, stage = list("stratified", "cluster", ""), 
            varnames = list("Strata", "Cluster", "ones"), 
            size = list(size1, size2, size3), 
            method = list("", "srswor", "srswor"))

sample <- getdata(data, s)[[3]]
sample$s.wt <- 1 / sample$Prob

# Extract variables
Y <- sample$y
X <- as.matrix(sample[, c("x1", "x2", "x3", "x4", "x5", "x6")])
A <- sample$z
w <- sample$s.wt

cat("\nSample size:", nrow(sample), "\n")
cat("Treated units:", sum(A == 1), "\n")
cat("Control units:", sum(A == 0), "\n")

# Create data structure for WDSM - use I() to protect matrix
sample_wdsm <- data.frame(
  X = I(X),  # I() prevents matrix expansion
  A = A,
  Y = Y,
  w = w
)

cat("\nStructure of sample_wdsm:\n")
str(sample_wdsm)

# Test fixed WDSM with debugging
cat("\n=== Running Fixed WDSM with debugging ===\n")

# Run without tryCatch first to see actual errors
wdsm_result <- wdsm_patt_prospective_v1_fixed(
  sample = sample_wdsm,
  M = 5,
  B = 50,  # Smaller for quick test
  show_progress = TRUE
)

cat("\nWDSM Fixed Results:\n")
cat("Estimate:", wdsm_result$tau_hat, "\n")
cat("SE:", wdsm_result$SE, "\n")
cat("95% CI:", wdsm_result$CI_lower, "-", wdsm_result$CI_upper, "\n")
cat("Coverage of true value:", 
    wdsm_result$CI_lower <= true_patt & wdsm_result$CI_upper >= true_patt, "\n")