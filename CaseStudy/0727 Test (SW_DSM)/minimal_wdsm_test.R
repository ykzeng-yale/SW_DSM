# Minimal WDSM Test
# Test if WDSM functions work with simple data

cat("Testing WDSM functions with minimal example...\n\n")

# Load required library
library(MatchIt)

# Source WDSM functions
source("WDSM/R/wdsmatchPATE_prospective.R")
source("WDSM/R/wdsmatchPATT_prospective.R")

# Create simple test data
set.seed(123)
n <- 500

# Covariates
X <- matrix(rnorm(n * 3), n, 3)
colnames(X) <- c("x1", "x2", "x3")

# Treatment assignment (based on propensity score)
ps_true <- plogis(0.5 * X[,1] - 0.3 * X[,2])
A <- rbinom(n, 1, ps_true)

# Outcome (with treatment effect = 2)
Y <- 1 + X[,1] + 0.5 * X[,2] - X[,3] + 2 * A + rnorm(n)

# Simple equal weights
weights <- rep(1, n)

cat("Data created:\n")
cat("n =", n, "\n")
cat("Treated units:", sum(A), "\n")
cat("Control units:", sum(1-A), "\n\n")

# Test PATE estimation
cat("Testing wdsmatchPATE_prospective...\n")
tryCatch({
  # Try with propensity score method only
  result_pate <- wdsmatchPATE_prospective(
    Y = Y, 
    X = X, 
    A = A, 
    weights = weights,
    method = "ps",
    ps = "fitted",
    boot = FALSE
  )
  
  cat("SUCCESS! PATE estimate:", result_pate$estimate, "\n")
  cat("Simple difference in means:", mean(Y[A==1]) - mean(Y[A==0]), "\n\n")
  
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  cat("Full error:\n")
  print(e)
})

# Test PATT estimation
cat("Testing wdsmatchPATT_prospective...\n")
tryCatch({
  result_patt <- wdsmatchPATT_prospective(
    Y = Y, 
    X = X, 
    A = A, 
    weights = weights,
    method = "ps",
    ps = "fitted",
    boot = FALSE
  )
  
  cat("SUCCESS! PATT estimate:", result_patt$estimate, "\n\n")
  
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  cat("Full error:\n")
  print(e)
})

# Check if it's a data type issue
cat("\nChecking data types:\n")
cat("class(Y):", class(Y), "\n")
cat("class(X):", class(X), "\n")
cat("class(A):", class(A), "\n")
cat("class(weights):", class(weights), "\n")
cat("typeof(X):", typeof(X), "\n")
cat("storage.mode(X):", storage.mode(X), "\n") 