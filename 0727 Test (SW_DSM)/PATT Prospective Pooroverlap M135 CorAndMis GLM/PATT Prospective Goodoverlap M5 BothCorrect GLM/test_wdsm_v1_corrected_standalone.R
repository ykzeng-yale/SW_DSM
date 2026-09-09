#!/usr/bin/env Rscript
# Test script for WDSM V1 Corrected version

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(mgcv)

# Set seed
set.seed(20250115)

# Source the corrected WDSM function
source("WDSM/R/wdsm_patt_prospective_v1_corrected.R")

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

# Test 1: Incorrect data structure (what the comparison script is doing)
cat("\n=== Test 1: Incorrect data structure ===\n")
sample_wdsm_wrong <- data.frame(
  X = X,  # This creates a single column with a matrix!
  A = A,
  Y = Y,
  w = w
)

cat("Structure of incorrect data frame:\n")
str(sample_wdsm_wrong)

# Test 2: Correct data structure - Method 1 (convert matrix to data frame first)
cat("\n=== Test 2: Correct data structure - Method 1 ===\n")
X_df <- as.data.frame(X)
colnames(X_df) <- c("x1", "x2", "x3", "x4", "x5", "x6")
sample_wdsm_correct1 <- data.frame(
  X_df,
  A = A,
  Y = Y,
  w = w
)

cat("Structure of correct data frame (method 1):\n")
str(sample_wdsm_correct1)

# Test 3: Correct data structure - Method 2 (use cbind)
cat("\n=== Test 3: Correct data structure - Method 2 ===\n")
sample_wdsm_correct2 <- data.frame(
  x1 = X[,1],
  x2 = X[,2],
  x3 = X[,3],
  x4 = X[,4],
  x5 = X[,5],
  x6 = X[,6],
  A = A,
  Y = Y,
  w = w
)

cat("Structure of correct data frame (method 2):\n")
str(sample_wdsm_correct2)

# Test 4: Create truly correct data structure with matrix column using I()
cat("\n=== Test 4: Correct data structure with matrix column using I() ===\n")

# Use I() to protect the matrix from being expanded
sample_wdsm_matrix <- data.frame(
  X = I(X),  # I() prevents matrix expansion
  A = A,
  Y = Y,
  w = w
)

cat("Structure of data frame with matrix column:\n")
str(sample_wdsm_matrix)
cat("Class of X column:", class(sample_wdsm_matrix$X), "\n")
cat("Is X a matrix?", is.matrix(sample_wdsm_matrix$X), "\n")

# Test 5: Run WDSM with matrix column structure
cat("\n=== Running WDSM Corrected with matrix structure ===\n")

tryCatch({
  wdsm_result <- wdsm_patt_prospective_v1_corrected(
    sample = sample_wdsm_matrix,
    M = 5,
    B = 50,  # Smaller for quick test
    show_progress = TRUE
  )
  
  cat("\nWDSM Corrected Results:\n")
  cat("Estimate:", wdsm_result$tau_hat, "\n")
  cat("SE:", wdsm_result$SE, "\n")
  cat("95% CI:", wdsm_result$CI_lower, "-", wdsm_result$CI_upper, "\n")
  cat("Coverage of true value:", 
      wdsm_result$CI_lower <= true_patt & wdsm_result$CI_upper >= true_patt, "\n")
  
}, error = function(e) {
  cat("Error running WDSM Corrected:", e$message, "\n")
})

# Test 6: Check if the original (non-corrected) version works
cat("\n=== Testing original WDSM V1 with matrix structure ===\n")
source("WDSM/R/wdsm_patt_prospective_v1.R")

tryCatch({
  wdsm_result_orig <- wdsm_patt_prospective_v1(
    sample = sample_wdsm_matrix,
    M = 5,
    B = 50,
    show_progress = TRUE
  )
  
  cat("\nOriginal WDSM Results:\n")
  cat("Estimate:", wdsm_result_orig$tau_hat, "\n")
  cat("SE:", wdsm_result_orig$SE, "\n")
  cat("95% CI:", wdsm_result_orig$CI_lower, "-", wdsm_result_orig$CI_upper, "\n")
  
}, error = function(e) {
  cat("Error running original WDSM:", e$message, "\n")
})