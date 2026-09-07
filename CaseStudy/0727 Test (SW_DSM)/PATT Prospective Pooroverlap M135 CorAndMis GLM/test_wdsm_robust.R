#!/usr/bin/env Rscript
# Test script for WDSM robust version with Ridge fallback

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(glmnet)  # For Ridge fallback

# Source the robust WDSM function
source("WDSM/R/wdsm_patt_prospective_v1_robust.R")

# Set seed
set.seed(20250115)

# Load population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_GoodOverlap_AllinOne_0118_2025
data <- data_sets[[1]]

# Test with 10 replicates
n_test <- 10
success_count <- 0
methods_used <- c()

cat("Testing WDSM robust version with Ridge fallback...\n")
cat("Running", n_test, "test replicates\n\n")

for (i in 1:n_test) {
  cat("Replicate", i, "... ")
  
  # Multi-stage sampling
  data$ones <- 1
  data$id <- seq_len(nrow(data))
  
  size1 <- rep(100000, 10)
  size2 <- rep(5, 10)
  size3 <- c(rep(850/5, 5), rep(750/5, 5), rep(700/5, 5), rep(650/5, 5), 
             rep(600/5, 5), rep(400/5, 5), rep(350/5, 5), rep(300/5, 5), 
             rep(250/5, 5), rep(150/5, 5))
  
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
  
  # Create data structure for WDSM
  sample_wdsm <- list(
    X = X,
    A = A,
    Y = Y,
    w = w
  )
  
  # Try running WDSM
  tryCatch({
    result <- wdsm_patt_prospective_v1_robust(
      sample = sample_wdsm,
      M = 5,
      B = 20,  # Small bootstrap for testing
      show_progress = FALSE
    )
    
    cat("SUCCESS - PS method:", result$ps_method_original, "\n")
    success_count <- success_count + 1
    methods_used <- c(methods_used, result$ps_method_original)
    
  }, error = function(e) {
    cat("FAILED -", e$message, "\n")
  })
}

cat("\n==================== SUMMARY ====================\n")
cat("Success rate:", success_count, "/", n_test, 
    "(", round(100 * success_count / n_test, 1), "%)\n")
cat("PS methods used:", paste(table(methods_used), collapse = ", "), "\n")
cat("=================================================\n")