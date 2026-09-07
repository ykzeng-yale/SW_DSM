################################################################################
# Execute WDSM Analysis for NHANES - Careful Step-by-Step Execution
################################################################################

# Clear workspace
rm(list = ls())

# Set working directory (if needed)
# setwd("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/NHANES")

# ==============================================================================
# STEP 1: Load Libraries
# ==============================================================================
cat("\n=== STEP 1: Loading Required Libraries ===\n")

required_packages <- c("MASS", "mvtnorm", "nnet", "dplyr", "tidyr", 
                      "purrr", "matrixStats", "survey", "sampling")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    cat("Installing", pkg, "\n")
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

cat("All libraries loaded successfully.\n")

# ==============================================================================
# STEP 2: Source WDSM Functions
# ==============================================================================
cat("\n=== STEP 2: Loading WDSM Functions ===\n")

# Check if file exists
if (!file.exists("WDSM PATE Retrospective.R")) {
  stop("WDSM PATE Retrospective.R not found!")
}

source("WDSM PATE Retrospective.R")
cat("WDSM functions loaded successfully.\n")

# ==============================================================================
# STEP 3: Load NHANES Data
# ==============================================================================
cat("\n=== STEP 3: Loading NHANES Data ===\n")

if (!file.exists("data/nhanes_complete_cases.rds")) {
  stop("NHANES data file not found!")
}

nhanes_data <- readRDS("data/nhanes_complete_cases.rds")
cat("Data loaded: n =", nrow(nhanes_data), "observations\n")
cat("Variables:", ncol(nhanes_data), "\n")

# ==============================================================================
# STEP 4: Prepare Data for WDSM
# ==============================================================================
cat("\n=== STEP 4: Preparing Data for WDSM ===\n")

# Check required variables exist
required_vars <- c("lTELOMEAN", "RACE_2CAT", "WTMEC4YR", 
                   "EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT",
                   "AGE", "SEX", "LBXWBCSI")

missing_vars <- setdiff(required_vars, names(nhanes_data))
if (length(missing_vars) > 0) {
  stop("Missing required variables: ", paste(missing_vars, collapse = ", "))
}

# Create simplified dataset for WDSM
# Note: The WDSM functions expect specific column names
wdsm_data <- data.frame(
  Y = nhanes_data$lTELOMEAN,
  A = nhanes_data$RACE_2CAT,
  survey_weight = nhanes_data$WTMEC4YR
)

# Add covariates - create design matrix
# For propensity score: SES variables
ses_vars <- c("EDUC_3CAT", "MARTL_3CAT", "PIR_3CAT", "EMPSTAT_4CAT", 
              "OCC_5CAT", "HHSIZE_5CAT", "HHINC_5CAT", "HIQ_2CAT", 
              "WIC_2CAT", "FDSEC_3CAT", "HOD_4CAT", "OWNHOME_2CAT")

# Check which SES variables exist
ses_vars_exist <- intersect(ses_vars, names(nhanes_data))
cat("Found", length(ses_vars_exist), "of", length(ses_vars), "SES variables\n")

# Add all variables to wdsm_data for model fitting
for (var in ses_vars_exist) {
  wdsm_data[[var]] <- nhanes_data[[var]]
}

# Add demographics and blood variables
demo_blood_vars <- c("AGE", "SEX", "LBXWBCSI", "LBXLYPCT", 
                     "LBXMOPCT", "LBXNEPCT", "LBXEOPCT", "LBXBAPCT")

for (var in demo_blood_vars) {
  if (var %in% names(nhanes_data)) {
    wdsm_data[[var]] <- nhanes_data[[var]]
  }
}

cat("Data preparation complete.\n")
cat("  Sample size:", nrow(wdsm_data), "\n")
cat("  Treated (Black):", sum(wdsm_data$A == 1), "\n")
cat("  Control (White):", sum(wdsm_data$A == 0), "\n")

# ==============================================================================
# STEP 5: Run WDSM Point Estimation
# ==============================================================================
cat("\n=== STEP 5: Running WDSM Point Estimation ===\n")

# Use the wdsm_point_estimate function from WDSM PATE Retrospective.R
# But we need to prepare the data in the format it expects

# The function expects certain column names, let me check and adapt
tryCatch({
  point_estimate <- wdsm_point_estimate(
    data = wdsm_data,
    M = 5,
    use_bias_correction = TRUE
  )
  
  cat("\nPoint Estimate Results:\n")
  cat("  PATE (tau_hat):", round(point_estimate$tau_hat, 4), "\n")
  cat("  E[Y(1)]:", round(point_estimate$mu1, 4), "\n")
  cat("  E[Y(0)]:", round(point_estimate$mu0, 4), "\n")
  
}, error = function(e) {
  cat("\nError in point estimation:\n")
  cat(as.character(e), "\n")
  cat("\nDebugging: Check data structure and function requirements\n")
  
  # Try a simpler approach
  cat("\nAttempting alternative approach...\n")
  
  # Let's create the matrices that WDSM expects
  # Create covariate matrix
  X_formula <- as.formula(paste("~ -1 +", 
                                paste(c(ses_vars_exist, "AGE", "SEX"), 
                                      collapse = " + ")))
  X <- model.matrix(X_formula, data = wdsm_data)
  
  # Store in expected format
  wdsm_data_alt <- wdsm_data
  
  # Add X columns with generic names
  for (i in 1:ncol(X)) {
    wdsm_data_alt[[paste0("X", i)]] <- X[, i]
  }
  
  # Try again with modified data
  point_estimate <<- tryCatch({
    wdsm_point_estimate(
      data = wdsm_data_alt,
      M = 5,
      use_bias_correction = TRUE
    )
  }, error = function(e2) {
    cat("Still failed:", as.character(e2), "\n")
    NULL
  })
})

# ==============================================================================
# STEP 6: Bootstrap Inference (if point estimate succeeded)
# ==============================================================================
if (exists("point_estimate") && !is.null(point_estimate)) {
  cat("\n=== STEP 6: Running Bootstrap Inference ===\n")
  cat("This may take several minutes...\n")
  
  tryCatch({
    boot_results <- method2_multinomial_bootstrap_ci(
      data = wdsm_data,
      indices = 1:nrow(wdsm_data),
      point_estimate = point_estimate,
      n_bootstrap = 100,  # Start with fewer for testing
      alpha = 0.05,
      use_bias_correction = TRUE,
      return_samples = FALSE
    )
    
    cat("\nBootstrap Results:\n")
    cat("  Standard Error:", round(boot_results$se, 4), "\n")
    cat("  95% CI: [", round(boot_results$ci_lower, 4), ", ",
        round(boot_results$ci_upper, 4), "]\n")
    
  }, error = function(e) {
    cat("\nError in bootstrap:\n")
    cat(as.character(e), "\n")
    boot_results <- NULL
  })
}

# ==============================================================================
# STEP 7: Summary of Results
# ==============================================================================
cat("\n")
cat("=" ,rep("=", 70), "\n", sep="")
cat("         WDSM ANALYSIS SUMMARY FOR NHANES\n")
cat("=" ,rep("=", 70), "\n", sep="")

if (exists("point_estimate") && !is.null(point_estimate)) {
  cat("\nPoint Estimate:\n")
  cat("  PATE =", round(point_estimate$tau_hat, 4), "\n")
  
  if (exists("boot_results") && !is.null(boot_results)) {
    cat("\nInference:\n")
    cat("  SE =", round(boot_results$se, 4), "\n")
    cat("  95% CI: [", round(boot_results$ci_lower, 4), ", ",
        round(boot_results$ci_upper, 4), "]\n")
    
    # Check significance
    if (boot_results$ci_lower > 0 || boot_results$ci_upper < 0) {
      cat("\n  Result: Statistically significant at α = 0.05\n")
    } else {
      cat("\n  Result: Not statistically significant at α = 0.05\n")
    }
  }
  
  cat("\nInterpretation:\n")
  cat("  After adjusting for socioeconomic status using WDSM,\n")
  if (point_estimate$tau_hat > 0) {
    cat("  Black individuals have", round(100*(exp(point_estimate$tau_hat)-1), 1), 
        "% longer telomeres on average.\n")
  } else {
    cat("  Black individuals have", round(100*(1-exp(point_estimate$tau_hat)), 1),
        "% shorter telomeres on average.\n")
  }
} else {
  cat("\nAnalysis did not complete successfully.\n")
  cat("Please check error messages above for debugging.\n")
}

cat("\n=== Analysis Complete ===\n")




