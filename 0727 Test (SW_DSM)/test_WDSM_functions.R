# Quick test of WDSM functions
# This script tests that all necessary functions are loaded and working

cat("Testing WDSM functions...\n\n")

# Load required libraries
library(survey)
library(sampling)
library(Matching)
library(MASS)

# Source WDSM functions
cat("Loading WDSM functions...\n")
tryCatch({
  source("WDSM/R/wdsmatchPATE_prospective.R")
  source("WDSM/R/wdsmatchPATE_retrospective.R")  
  source("WDSM/R/wdsmatchPATT_prospective.R")
  source("WDSM/R/wdsmatchPATT_retrospective.R")
  source("WDSM/R/bootstrap_wdsm.R")
  cat("✓ All WDSM functions loaded successfully\n\n")
}, error = function(e) {
  cat("✗ Error loading WDSM functions:\n")
  print(e)
  stop("Cannot proceed without WDSM functions")
})

# Source SW_PSW functions
cat("Loading SW_PSW functions...\n")
tryCatch({
  source("SW_PSW-main/Shared_PSW_MOM_CVR_WET_Function.R")
  source("SW_PSW-main/EstSOD_Function.R")
  cat("✓ All SW_PSW functions loaded successfully\n\n")
}, error = function(e) {
  cat("✗ Error loading SW_PSW functions:\n")
  print(e)
  stop("Cannot proceed without SW_PSW functions")
})

# Test with simple simulated data
cat("Creating test data...\n")
set.seed(123)
n <- 500

# Generate simple test data
X <- matrix(rnorm(n * 3), ncol = 3)
colnames(X) <- c("x1", "x2", "x3")

# True propensity score
ps_true <- plogis(-0.5 + 0.5*X[,1] - 0.3*X[,2] + 0.2*X[,3])
A <- rbinom(n, 1, ps_true)

# True outcome model
Y0 <- 1 + X[,1] + 0.5*X[,2] + rnorm(n, 0, 0.5)
Y1 <- Y0 + 2 + 0.5*X[,1]
Y <- A * Y1 + (1-A) * Y0

# Survey weights (simple uniform for test)
weights <- rep(2, n)  # Uniform weights

cat("Test data created: n =", n, ", p =", ncol(X), "\n")
cat("Treatment prevalence:", mean(A), "\n\n")

# Test 1: Prospective PATE
cat("Test 1: WDSM PATE with prospective sampling...\n")
test1 <- tryCatch({
  result <- wdsmatchPATE_prospective(
    Y = Y, X = X, A = A, weights = weights,
    method = "dsm",
    model.ps = "logit",
    model.pg = "glm",
    M = 1,  # Use M=1 for speed
    bias.correct = FALSE,
    varest = FALSE
  )
  cat("✓ PATE estimate:", result$est.dsm, "\n")
  TRUE
}, error = function(e) {
  cat("✗ Error in prospective PATE:\n")
  print(e)
  FALSE
})

# Test 2: Prospective PATT
cat("\nTest 2: WDSM PATT with prospective sampling...\n")
test2 <- tryCatch({
  result <- wdsmatchPATT_prospective(
    Y = Y, X = X, A = A, weights = weights,
    method = "dsm",
    model.ps = "logit",
    model.pg = "glm",
    M = 1,
    bias.correct = FALSE,
    varest = FALSE
  )
  cat("✓ PATT estimate:", result$est.dsm, "\n")
  TRUE
}, error = function(e) {
  cat("✗ Error in prospective PATT:\n")
  print(e)
  FALSE
})

# Test 3: Retrospective PATE
cat("\nTest 3: WDSM PATE with retrospective sampling...\n")
# For retrospective, we need treatment-specific weights
weights0 <- weights * 1.2  # Different weights for control
weights1 <- weights * 0.8  # Different weights for treated

test3 <- tryCatch({
  result <- wdsmatchPATE_retrospective(
    Y = Y, X = X, A = A, 
    weights0 = weights0, weights1 = weights1,
    method = "dsm",
    model.ps = "logit",
    model.pg = "glm",
    M = 1,
    bias.correct = FALSE,
    varest = FALSE
  )
  cat("✓ PATE estimate:", result$est.dsm, "\n")
  TRUE
}, error = function(e) {
  cat("✗ Error in retrospective PATE:\n")
  print(e)
  FALSE
})

# Test 4: Retrospective PATT
cat("\nTest 4: WDSM PATT with retrospective sampling...\n")
test4 <- tryCatch({
  result <- wdsmatchPATT_retrospective(
    Y = Y, X = X, A = A,
    weights0 = weights0, weights1 = weights1,
    method = "dsm",
    model.ps = "logit",
    model.pg = "glm",
    M = 1,
    bias.correct = FALSE,
    varest = FALSE
  )
  cat("✓ PATT estimate:", result$est.dsm, "\n")
  TRUE
}, error = function(e) {
  cat("✗ Error in retrospective PATT:\n")
  print(e)
  FALSE
})

# Summary
cat("\n" ,rep("=", 50), "\n", sep = "")
cat("TEST SUMMARY:\n")
cat("Prospective PATE:", ifelse(test1, "PASSED ✓", "FAILED ✗"), "\n")
cat("Prospective PATT:", ifelse(test2, "PASSED ✓", "FAILED ✗"), "\n")
cat("Retrospective PATE:", ifelse(test3, "PASSED ✓", "FAILED ✗"), "\n")
cat("Retrospective PATT:", ifelse(test4, "PASSED ✓", "FAILED ✗"), "\n")

all_passed <- all(c(test1, test2, test3, test4))
if (all_passed) {
  cat("\nAll tests passed! Ready to run full simulation.\n")
} else {
  cat("\nSome tests failed. Please check error messages above.\n")
} 