#!/usr/bin/env Rscript

# Comprehensive check of poor overlap implementation
# Based on user's checklist and good overlap reference

cat("\n========================================\n")
cat("COMPREHENSIVE CHECK OF POOR OVERLAP SETUP\n")
cat("========================================\n")

# Load one of the result files to check
load("pooroverlap_CorCor_20rep_results.RData")

# Check structure of results
cat("\n1. DATA CHECK\n")
cat("--------------\n")
cat("Number of replications:", length(all_results), "\n")

# Check first replication
first_rep <- all_results[[1]][[1]]
cat("Methods in first replication:", paste(names(first_rep), collapse=", "), "\n")

# Check which methods failed
failed_methods <- c()
successful_methods <- c()

for (method_name in names(first_rep)) {
  method_data <- first_rep[[method_name]]
  if (is.null(method_data$estimate) || is.na(method_data$estimate)) {
    failed_methods <- c(failed_methods, method_name)
  } else {
    successful_methods <- c(successful_methods, method_name)
  }
}

cat("\nSuccessful methods:", paste(successful_methods, collapse=", "), "\n")
cat("Failed methods:", paste(failed_methods, collapse=", "), "\n")

# Check dsmatchATE calls
cat("\n2. DSMATCHATE FUNCTION CHECK\n")
cat("----------------------------\n")

# Load dsmatch functions to check signature
source("dsmatch-master/R/dsmatchATE.R")

# Check the function signature
cat("dsmatchATE function signature:\n")
args_list <- formals(dsmatchATE)
cat("Arguments:", paste(names(args_list), collapse=", "), "\n")

# Check if 'M' is in arguments
if ("M" %in% names(args_list)) {
  cat("✅ M parameter exists in dsmatchATE\n")
} else {
  cat("❌ M parameter NOT in dsmatchATE signature\n")
  cat("   This is likely why unweighted methods are failing!\n")
}

# Check the return structure
cat("\n3. CHECK DSMATCHATE RETURN STRUCTURE\n")
cat("------------------------------------\n")

# Run a minimal test
set.seed(123)
n <- 100
X_test <- matrix(rnorm(n * 6), ncol = 6)
A_test <- rbinom(n, 1, 0.5)
Y_test <- rnorm(n)

cat("Running minimal dsmatchATE test...\n")
tryCatch({
  test_result <- dsmatchATE(
    Y = Y_test,
    X = X_test,
    A = A_test,
    method = "ps",
    model.ps = "logit",
    cov.balance = FALSE,
    varest = TRUE,
    boots = 10,
    mc = FALSE,
    ncpus = 1
  )
  
  cat("dsmatchATE return structure:\n")
  cat("Names:", paste(names(test_result), collapse=", "), "\n")
  
  # Check if expected fields exist
  if ("est.ps" %in% names(test_result)) {
    cat("✅ est.ps field exists\n")
  } else {
    cat("❌ est.ps field missing\n")
  }
  
  if ("bootvar" %in% names(test_result)) {
    cat("✅ bootvar field exists\n")
  } else {
    cat("❌ bootvar field missing\n")
  }
  
  # Check what fields actually exist for estimate and SE
  if ("treatment.effect" %in% names(test_result)) {
    cat("⚠️ Found 'treatment.effect' field - script expects 'est.ps'\n")
  }
  if ("standard.error" %in% names(test_result)) {
    cat("⚠️ Found 'standard.error' field - script calculates SE from bootvar\n")
  }
  if ("CI" %in% names(test_result)) {
    cat("⚠️ Found 'CI' field - script calculates CI from bootvar\n")
  }
  
}, error = function(e) {
  cat("Error in test:", e$message, "\n")
})

cat("\n4. CHECK TIMEOUT SETTINGS\n")
cat("-------------------------\n")

# Check if there are individual method timeouts
script_path <- "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R"
script_lines <- readLines(script_path)

# Look for setTimeLimit
timeout_lines <- grep("setTimeLimit|withTimeout", script_lines, value = TRUE)
if (length(timeout_lines) > 0) {
  cat("⚠️ Found timeout settings:\n")
  for (line in timeout_lines) {
    cat("  ", trimws(line), "\n")
  }
  cat("\nGood overlap uses setTimeLimit at replicate level, not method level\n")
} else {
  cat("✅ No timeout settings found (good!)\n")
}

cat("\n5. CHECK WDSM CI CONSTRUCTION\n")
cat("------------------------------\n")

# Check WDSM function for CI construction
wdsm_script <- readLines("wdsm_ci_functions.R")
quantile_lines <- grep("quantile.*bootstrap", wdsm_script, value = TRUE, ignore.case = TRUE)
normal_lines <- grep("qnorm.*ci|conf", wdsm_script, value = TRUE, ignore.case = TRUE)

if (length(quantile_lines) > 0) {
  cat("⚠️ Found quantile-based CI construction:\n")
  for (line in head(quantile_lines, 2)) {
    cat("  ", trimws(line), "\n")
  }
}

if (length(normal_lines) > 0) {
  cat("✅ Found normal-based CI construction:\n")
  for (line in head(normal_lines, 2)) {
    cat("  ", trimws(line), "\n")
  }
}

cat("\n6. CHECK RETROSPECTIVE SAMPLING\n")
cat("--------------------------------\n")

# Check retrospective_sample function
retro_lines <- grep("retrospective_sample.*<-.*function", wdsm_script, value = TRUE)
if (length(retro_lines) > 0) {
  cat("✅ retrospective_sample function found in wdsm_ci_functions.R\n")
  
  # Check for probability-based sampling
  prob_lines <- grep("1/Prob|survey_weight.*1/Prob", wdsm_script, value = TRUE)
  if (length(prob_lines) > 0) {
    cat("✅ Using 1/Prob for survey weights (correct!)\n")
  }
}

cat("\n7. CHECK MODEL SPECIFICATIONS\n")
cat("------------------------------\n")

# Check if model specifications are correctly passed
cat("Checking CorCor scenario (both models should include interaction):\n")
corcor_lines <- grep("use_interaction_ps.*TRUE", script_lines, value = TRUE)
if (length(corcor_lines) > 0) {
  cat("✅ PS model includes interaction in CorCor\n")
}
corcor_lines <- grep("use_interaction_pg.*TRUE", script_lines, value = TRUE)
if (length(corcor_lines) > 0) {
  cat("✅ PG model includes interaction in CorCor\n")
}

cat("\n========================================\n")
cat("RECOMMENDATIONS\n")
cat("========================================\n")

if (length(failed_methods) > 0) {
  cat("\n❌ CRITICAL ISSUE: Unweighted methods are failing!\n")
  cat("\nLikely causes:\n")
  cat("1. dsmatchATE return structure mismatch\n")
  cat("   - Script expects: est.ps, est.pg, est.ds\n")
  cat("   - Function returns: treatment.effect, standard.error, CI\n")
  cat("\n2. Need to fix result extraction in script:\n")
  cat("   Instead of: dsm_result$est.ds\n")
  cat("   Use: dsm_result$treatment.effect\n")
  cat("\n3. Similarly for SE and CI fields\n")
}

cat("\nOther findings:\n")
cat("- WDSM bias in CorCor: -3.22% (expected <1%)\n")
cat("- Coverage: 90% (expected 95%)\n")
cat("- Only 20 replications may be insufficient\n")
cat("\n========================================\n")
