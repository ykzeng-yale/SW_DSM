#!/usr/bin/env Rscript
# Test script comparing different WDSM versions

# Load required libraries
library(survey)
library(sampling)
library(MASS)
library(boot)
library(glmnet)

# Source all WDSM versions
source("WDSM/R/wdsm_patt_prospective_v1_simplified.R")  # Original with manual bootstrap
source("WDSM/R/wdsm_patt_prospective_v1_robust.R")      # Robust with Ridge fallback
source("WDSM/R/wdsm_patt_prospective_v2_boot.R")        # New version using boot package

# Set seed
set.seed(20250115)

# Load population data
load("SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData")
data_sets <- SuperPopGen_GoodOverlap_AllinOne_0118_2025
data <- data_sets[[1]]

# Test parameters
n_test <- 5
M <- 5
B <- 100  # Small bootstrap for testing

cat("========================================================\n")
cat("Comparing WDSM Versions:\n")
cat("1. V1 Simplified (manual bootstrap, quasibinomial)\n")
cat("2. V1 Robust (manual bootstrap, Ridge fallback)\n")
cat("3. V2 Boot (boot package, like dsmatch)\n")
cat("========================================================\n\n")

# Store results
results <- list(
  v1_simplified = list(),
  v1_robust = list(),
  v2_boot = list()
)

for (i in 1:n_test) {
  cat("\n--- Replicate", i, "---\n")
  
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
  
  # Test V1 Simplified
  cat("\nTesting V1 Simplified... ")
  start_time <- Sys.time()
  tryCatch({
    result_v1s <- wdsm_patt_prospective_v1_simplified(
      Y = Y, X = X, A = A, w = w,
      M = M, B = B, show_progress = FALSE
    )
    elapsed <- as.numeric(Sys.time() - start_time, units = "secs")
    cat("SUCCESS (", round(elapsed, 1), "s)\n", sep = "")
    cat("  Estimate:", round(result_v1s$tau_hat, 4), 
        " SE:", round(result_v1s$SE, 4), "\n")
    
    results$v1_simplified[[i]] <- list(
      success = TRUE,
      estimate = result_v1s$tau_hat,
      se = result_v1s$SE,
      time = elapsed
    )
  }, error = function(e) {
    cat("FAILED -", e$message, "\n")
    results$v1_simplified[[i]] <- list(success = FALSE)
  })
  
  # Test V1 Robust
  cat("\nTesting V1 Robust... ")
  start_time <- Sys.time()
  tryCatch({
    result_v1r <- wdsm_patt_prospective_v1_robust(
      sample = data.frame(X = X, A = A, Y = Y, w = w),
      M = M, B = B, show_progress = FALSE
    )
    elapsed <- as.numeric(Sys.time() - start_time, units = "secs")
    cat("SUCCESS (", round(elapsed, 1), "s) - PS method: ", 
        result_v1r$ps_method_original, "\n", sep = "")
    cat("  Estimate:", round(result_v1r$tau_hat, 4), 
        " SE:", round(result_v1r$SE, 4), "\n")
    
    results$v1_robust[[i]] <- list(
      success = TRUE,
      estimate = result_v1r$tau_hat,
      se = result_v1r$SE,
      ps_method = result_v1r$ps_method_original,
      time = elapsed
    )
  }, error = function(e) {
    cat("FAILED -", e$message, "\n")
    results$v1_robust[[i]] <- list(success = FALSE)
  })
  
  # Test V2 Boot
  cat("\nTesting V2 Boot... ")
  start_time <- Sys.time()
  tryCatch({
    result_v2b <- wdsm_patt_prospective_v2_boot(
      Y = Y, X = X, A = A, w = w,
      M = M, B = B, parallel = FALSE, show_progress = FALSE
    )
    elapsed <- as.numeric(Sys.time() - start_time, units = "secs")
    cat("SUCCESS (", round(elapsed, 1), "s) - PS method: ", 
        result_v2b$ps_method_original, "\n", sep = "")
    cat("  Estimate:", round(result_v2b$tau_hat, 4), 
        " SE:", round(result_v2b$SE, 4), "\n")
    
    results$v2_boot[[i]] <- list(
      success = TRUE,
      estimate = result_v2b$tau_hat,
      se = result_v2b$SE,
      ps_method = result_v2b$ps_method_original,
      time = elapsed
    )
  }, error = function(e) {
    cat("FAILED -", e$message, "\n")
    results$v2_boot[[i]] <- list(success = FALSE)
  })
}

# Summarize results
cat("\n\n========================================================\n")
cat("SUMMARY OF RESULTS\n")
cat("========================================================\n\n")

for (method in names(results)) {
  cat("\n", method, ":\n", sep = "")
  
  success_count <- sum(sapply(results[[method]], function(x) x$success))
  cat("  Success rate: ", success_count, "/", n_test, " (", 
      round(100 * success_count / n_test, 1), "%)\n", sep = "")
  
  successful <- results[[method]][sapply(results[[method]], function(x) x$success)]
  if (length(successful) > 0) {
    estimates <- sapply(successful, function(x) x$estimate)
    ses <- sapply(successful, function(x) x$se)
    times <- sapply(successful, function(x) x$time)
    
    cat("  Mean estimate: ", round(mean(estimates), 4), "\n")
    cat("  Mean SE: ", round(mean(ses), 4), "\n")
    cat("  Mean time: ", round(mean(times), 1), "s\n")
    
    # PS methods for robust versions
    if (method %in% c("v1_robust", "v2_boot")) {
      ps_methods <- sapply(successful, function(x) x$ps_method)
      cat("  PS methods used: ", paste(unique(ps_methods), collapse = ", "), "\n")
    }
  }
}

cat("\n========================================================\n")

# Test parallel bootstrap for V2
cat("\nTesting V2 Boot with parallel processing (2 cores)...\n")
start_time <- Sys.time()
tryCatch({
  result_v2b_par <- wdsm_patt_prospective_v2_boot(
    Y = Y, X = X, A = A, w = w,
    M = M, B = B, parallel = 2, show_progress = TRUE
  )
  elapsed <- as.numeric(Sys.time() - start_time, units = "secs")
  cat("\nParallel bootstrap completed in", round(elapsed, 1), "seconds\n")
}, error = function(e) {
  cat("Parallel bootstrap failed:", e$message, "\n")
})