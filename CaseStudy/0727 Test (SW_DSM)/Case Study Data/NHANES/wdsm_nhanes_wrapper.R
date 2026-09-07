################################################################################
# WDSM Wrapper for NHANES Data
# Adapts NHANES data to work with existing WDSM functions
################################################################################

# Function to prepare NHANES data for WDSM functions
prepare_nhanes_for_wdsm <- function(nhanes_data) {
  
  # Create numeric versions of factor variables
  # The WDSM functions expect numeric X1, X2, etc.
  
  # First, let's create a design matrix from our categorical variables
  # We'll use the SES variables for the main analysis
  
  # Create formula for design matrix (exclude intercept)
  formula_ses <- ~ -1 + EDUC_3CAT + MARTL_3CAT + PIR_3CAT + 
                   EMPSTAT_4CAT + OCC_5CAT + HHSIZE_5CAT
  
  # Create design matrix for SES variables
  X_ses <- model.matrix(formula_ses, data = nhanes_data)
  
  # For simplicity, we'll use the first 6 principal components or most important variables
  # This matches the X1-X6 structure expected by WDSM
  
  # Alternative approach: Select 6 key variables
  # We'll use numeric versions of key predictors
  
  wdsm_data <- data.frame(
    Y = nhanes_data$lTELOMEAN,
    A = nhanes_data$RACE_2CAT,
    survey_weight = nhanes_data$WTMEC4YR
  )
  
  # Create X1-X6 as numeric representations of key variables
  # X1: Education (numeric encoding)
  wdsm_data$X1 <- as.numeric(nhanes_data$EDUC_3CAT) - 1  # 0, 1, 2, 3
  
  # X2: Poverty-Income Ratio (numeric encoding)  
  wdsm_data$X2 <- as.numeric(nhanes_data$PIR_3CAT) - 1  # 0, 1, 2, 3
  
  # X3: Age (already numeric, standardized)
  wdsm_data$X3 <- scale(nhanes_data$AGE)[,1]
  
  # X4: Household income (numeric encoding)
  wdsm_data$X4 <- as.numeric(nhanes_data$HHINC_5CAT) - 1  # 0-5
  
  # X5: White blood cell count (standardized)
  wdsm_data$X5 <- scale(nhanes_data$LBXWBCSI)[,1]
  
  # X6: Employment status (numeric encoding)
  wdsm_data$X6 <- as.numeric(nhanes_data$EMPSTAT_4CAT) - 1  # 0-4
  
  return(wdsm_data)
}

# Custom WDSM point estimate function for NHANES
wdsm_nhanes_point_estimate <- function(nhanes_data, M = 5, use_bias_correction = TRUE) {
  
  # Prepare data in format expected by WDSM
  wdsm_data <- prepare_nhanes_for_wdsm(nhanes_data)
  
  # Now call the original WDSM function
  result <- wdsm_point_estimate(
    data = wdsm_data,
    M = M,
    use_bias_correction = use_bias_correction
  )
  
  return(result)
}

# Alternative: Create a more comprehensive version using all covariates
prepare_nhanes_full <- function(nhanes_data) {
  
  # Start with basic variables
  wdsm_data <- data.frame(
    Y = nhanes_data$lTELOMEAN,
    A = nhanes_data$RACE_2CAT,
    survey_weight = nhanes_data$WTMEC4YR
  )
  
  # Use PCA to reduce dimensionality to 6 components
  # First create a complete numeric matrix
  
  # Convert factors to numeric
  numeric_data <- data.frame(
    educ = as.numeric(nhanes_data$EDUC_3CAT),
    martl = as.numeric(nhanes_data$MARTL_3CAT),
    pir = as.numeric(nhanes_data$PIR_3CAT),
    empstat = as.numeric(nhanes_data$EMPSTAT_4CAT),
    occ = as.numeric(nhanes_data$OCC_5CAT),
    hhsize = as.numeric(nhanes_data$HHSIZE_5CAT),
    hhinc = as.numeric(nhanes_data$HHINC_5CAT),
    hiq = as.numeric(nhanes_data$HIQ_2CAT),
    wic = as.numeric(nhanes_data$WIC_2CAT),
    fdsec = as.numeric(nhanes_data$FDSEC_3CAT),
    hod = as.numeric(nhanes_data$HOD_4CAT),
    ownhome = as.numeric(nhanes_data$OWNHOME_2CAT),
    age = nhanes_data$AGE,
    sex = as.numeric(nhanes_data$SEX),
    wbc = nhanes_data$LBXWBCSI,
    lymph = nhanes_data$LBXLYPCT,
    mono = nhanes_data$LBXMOPCT,
    neut = nhanes_data$LBXNEPCT,
    eos = nhanes_data$LBXEOPCT,
    baso = nhanes_data$LBXBAPCT
  )
  
  # Handle any remaining NAs
  numeric_data[is.na(numeric_data)] <- 0
  
  # Standardize
  numeric_data_std <- scale(numeric_data)
  
  # Run PCA
  pca_result <- prcomp(numeric_data_std, center = FALSE, scale. = FALSE)
  
  # Take first 6 components
  pca_scores <- pca_result$x[, 1:6]
  
  # Add as X1-X6
  for (i in 1:6) {
    wdsm_data[[paste0("X", i)]] <- pca_scores[, i]
  }
  
  return(wdsm_data)
}

# Run complete NHANES analysis with WDSM
run_nhanes_wdsm_analysis <- function(nhanes_data, method = "simple", M = 5, 
                                     n_bootstrap = 100, use_bias_correction = TRUE) {
  
  cat("\n=== Preparing NHANES Data for WDSM ===\n")
  
  # Choose preparation method
  if (method == "simple") {
    cat("Using simple variable encoding...\n")
    wdsm_data <- prepare_nhanes_for_wdsm(nhanes_data)
  } else if (method == "pca") {
    cat("Using PCA dimension reduction...\n")
    wdsm_data <- prepare_nhanes_full(nhanes_data)
  } else {
    stop("Method must be 'simple' or 'pca'")
  }
  
  cat("Data prepared with", ncol(wdsm_data) - 3, "covariate dimensions\n")
  
  # Run point estimation
  cat("\n=== Running WDSM Point Estimation ===\n")
  point_est <- wdsm_point_estimate(
    data = wdsm_data,
    M = M,
    use_bias_correction = use_bias_correction
  )
  
  cat("Point estimate completed.\n")
  cat("  PATE =", round(point_est$tau_hat, 4), "\n")
  
  # Run bootstrap
  cat("\n=== Running Bootstrap Inference ===\n")
  cat("This may take several minutes...\n")
  
  boot_result <- method2_multinomial_bootstrap_ci(
    data = wdsm_data,
    indices = 1:nrow(wdsm_data),
    point_estimate = point_est,
    n_bootstrap = n_bootstrap,
    alpha = 0.05,
    use_bias_correction = use_bias_correction,
    return_samples = FALSE
  )
  
  cat("Bootstrap completed.\n")
  
  # Return results
  return(list(
    data = wdsm_data,
    point_estimate = point_est,
    bootstrap = boot_result,
    method = method
  ))
}




