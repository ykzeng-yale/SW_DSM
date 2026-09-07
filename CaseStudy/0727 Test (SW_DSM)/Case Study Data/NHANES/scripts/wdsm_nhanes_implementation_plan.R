################################################################################
# WDSM Implementation Plan for NHANES Telomere Length Analysis
# Using Actual NHANES Variable Names and Proper Survey Weight Incorporation
################################################################################

# ==============================================================================
# PART 1: DATA PREPARATION WITH ACTUAL NHANES VARIABLES
# ==============================================================================

prepare_nhanes_for_wdsm <- function() {
  # Load NHANES data with complete cases
  nhanes <- readRDS("data/nhanes_complete_cases.rds")
  
  # Extract key variables using EXACT NHANES names
  data_wdsm <- list(
    # Outcome: Log-transformed telomere length
    Y = nhanes$lTELOMEAN,
    
    # Treatment: Race (1 = Non-Hispanic Black, 0 = Non-Hispanic White)
    A = nhanes$RACE_2CAT,
    
    # Survey weights (CRITICAL for NHANES)
    survey_weight = nhanes$WTMEC4YR,
    
    # Sample size info
    n = nrow(nhanes),
    n_treated = sum(nhanes$RACE_2CAT == 1),
    n_control = sum(nhanes$RACE_2CAT == 0)
  )
  
  # Create covariate matrix using ACTUAL NHANES variable names
  # Following Salerno et al.'s specification: 12 SES + demographics + blood
  
  # SES Variables (12 indicators as used in paper)
  ses_formula <- ~ EDUC_3CAT + MARTL_3CAT + PIR_3CAT + EMPSTAT_4CAT + 
                    OCC_5CAT + HHSIZE_5CAT + HHINC_5CAT + HIQ_2CAT + 
                    WIC_2CAT + FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT
  
  # Demographics
  demo_formula <- ~ AGE + SEX
  
  # Blood composition (6 variables)
  blood_formula <- ~ LBXWBCSI + LBXLYPCT + LBXMOPCT + 
                     LBXNEPCT + LBXEOPCT + LBXBAPCT
  
  # Combine all covariates
  full_formula <- ~ EDUC_3CAT + MARTL_3CAT + PIR_3CAT + EMPSTAT_4CAT + 
                    OCC_5CAT + HHSIZE_5CAT + HHINC_5CAT + HIQ_2CAT + 
                    WIC_2CAT + FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT +
                    AGE + SEX + 
                    LBXWBCSI + LBXLYPCT + LBXMOPCT + 
                    LBXNEPCT + LBXEOPCT + LBXBAPCT
  
  # Create design matrix (removing intercept)
  X_matrix <- model.matrix(full_formula, data = nhanes)[, -1]
  
  # Store in data list
  data_wdsm$X <- X_matrix
  data_wdsm$X_names <- colnames(X_matrix)
  
  # Add original data frame for model fitting
  data_wdsm$df <- nhanes
  
  return(data_wdsm)
}

# ==============================================================================
# PART 2: PROPENSITY SCORE ESTIMATION WITH SURVEY WEIGHTS
# ==============================================================================

estimate_propensity_score_nhanes <- function(data_wdsm) {
  # Following Salerno et al.'s approach but with survey weights
  # Using quasibinomial for survey-weighted logistic regression
  
  ps_formula <- RACE_2CAT ~ EDUC_3CAT + MARTL_3CAT + PIR_3CAT + 
                            EMPSTAT_4CAT + OCC_5CAT + HHSIZE_5CAT + 
                            HHINC_5CAT + HIQ_2CAT + WIC_2CAT + 
                            FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT
  
  # CRITICAL: Use survey weights in propensity score estimation
  ps_model <- glm(ps_formula,
                  data = data_wdsm$df,
                  family = quasibinomial(link = "logit"),
                  weights = data_wdsm$survey_weight)
  
  # Extract fitted values
  e_score <- ps_model$fitted.values
  
  # Check for extreme propensity scores
  cat("\nPropensity Score Summary:\n")
  cat("Min:", round(min(e_score), 4), "\n")
  cat("Max:", round(max(e_score), 4), "\n")
  cat("Mean:", round(mean(e_score), 4), "\n")
  
  # Check overlap
  overlap_check <- sum(e_score > 0.1 & e_score < 0.9) / length(e_score)
  cat("Proportion with good overlap (0.1 < e < 0.9):", 
      round(overlap_check, 3), "\n")
  
  return(list(
    e_score = e_score,
    ps_model = ps_model
  ))
}

# ==============================================================================
# PART 3: PROGNOSTIC SCORE ESTIMATION WITH SURVEY WEIGHTS
# ==============================================================================

estimate_prognostic_scores_nhanes <- function(data_wdsm) {
  # Estimate E[Y(0)|X] using control units
  # Include all confounders plus blood composition for outcome prediction
  
  prog_formula <- lTELOMEAN ~ EDUC_3CAT + MARTL_3CAT + PIR_3CAT + 
                              EMPSTAT_4CAT + OCC_5CAT + HHSIZE_5CAT + 
                              HHINC_5CAT + HIQ_2CAT + WIC_2CAT + 
                              FDSEC_3CAT + HOD_4CAT + OWNHOME_2CAT +
                              AGE + SEX +
                              LBXWBCSI + LBXLYPCT + LBXMOPCT + 
                              LBXNEPCT + LBXEOPCT + LBXBAPCT
  
  # Fit separate models for treated and control
  # CRITICAL: Use survey weights in outcome models
  
  # Model for Y(0) using control units
  control_idx <- which(data_wdsm$A == 0)
  prog0_model <- lm(prog_formula,
                    data = data_wdsm$df[control_idx, ],
                    weights = data_wdsm$survey_weight[control_idx])
  
  # Predict Y(0) for all units
  psi0 <- predict(prog0_model, newdata = data_wdsm$df)
  
  # Model for Y(1) using treated units  
  treated_idx <- which(data_wdsm$A == 1)
  prog1_model <- lm(prog_formula,
                    data = data_wdsm$df[treated_idx, ],
                    weights = data_wdsm$survey_weight[treated_idx])
  
  # Predict Y(1) for all units
  psi1 <- predict(prog1_model, newdata = data_wdsm$df)
  
  cat("\nPrognostic Score Summary:\n")
  cat("Psi0 - Mean:", round(mean(psi0), 4), 
      "SD:", round(sd(psi0), 4), "\n")
  cat("Psi1 - Mean:", round(mean(psi1), 4), 
      "SD:", round(sd(psi1), 4), "\n")
  
  return(list(
    psi0 = psi0,
    psi1 = psi1,
    prog0_model = prog0_model,
    prog1_model = prog1_model
  ))
}

# ==============================================================================
# PART 4: POLYNOMIAL SIEVE BIAS CORRECTION
# ==============================================================================

apply_polynomial_sieve_correction <- function(data_wdsm, e_score, psi0, psi1) {
  # Following the polynomial sieve method from WDSM paper
  # This addresses finite-sample bias in prognostic score estimation
  
  Y <- data_wdsm$Y
  A <- data_wdsm$A
  w <- data_wdsm$survey_weight
  
  # For control outcome model (mu0)
  sieve_vars_0 <- cbind(
    mu0 = psi0,
    mu0_sq = psi0^2,
    ps = e_score,
    ps_sq = e_score^2,
    ps_mu0 = e_score * psi0
  )
  
  # Fit bias correction model on control units
  control_idx <- which(A == 0)
  bc0_data <- data.frame(Y = Y[control_idx], sieve_vars_0[control_idx, ])
  
  bc0_model <- lm(Y ~ mu0 + mu0_sq + ps + ps_sq + ps_mu0,
                   data = bc0_data,
                   weights = w[control_idx])
  
  # Get bias-corrected mu0 predictions for all units
  mu0_bc <- predict(bc0_model, newdata = data.frame(sieve_vars_0))
  
  # For treated outcome model (mu1)
  sieve_vars_1 <- cbind(
    mu1 = psi1,
    mu1_sq = psi1^2,
    ps = e_score,
    ps_sq = e_score^2,
    ps_mu1 = e_score * psi1
  )
  
  # Fit bias correction model on treated units
  treated_idx <- which(A == 1)
  bc1_data <- data.frame(Y = Y[treated_idx], sieve_vars_1[treated_idx, ])
  
  bc1_model <- lm(Y ~ mu1 + mu1_sq + ps + ps_sq + ps_mu1,
                   data = bc1_data,
                   weights = w[treated_idx])
  
  # Get bias-corrected mu1 predictions for all units
  mu1_bc <- predict(bc1_model, newdata = data.frame(sieve_vars_1))
  
  cat("\nBias Correction Applied:\n")
  cat("Original vs Corrected Psi0 - Mean difference:", 
      round(mean(mu0_bc - psi0), 4), "\n")
  cat("Original vs Corrected Psi1 - Mean difference:", 
      round(mean(mu1_bc - psi1), 4), "\n")
  
  return(list(
    mu0_bc = mu0_bc,
    mu1_bc = mu1_bc,
    bc0_model = bc0_model,
    bc1_model = bc1_model
  ))
}

# ==============================================================================
# PART 5: DOUBLE SCORE MATCHING WITH M=5
# ==============================================================================

perform_double_score_matching <- function(data_wdsm, e_score, mu0_bc, mu1_bc, M = 5) {
  n <- data_wdsm$n
  A <- data_wdsm$A
  
  # Create double scores for each treatment group
  # D0 for matching to estimate Y(0)
  D0 <- cbind(e_score, mu0_bc)
  
  # D1 for matching to estimate Y(1)
  D1 <- cbind(e_score, mu1_bc)
  
  # Standardize double scores using weighted mean and SD
  D0_std <- standardize_with_weights(D0, data_wdsm$survey_weight)
  D1_std <- standardize_with_weights(D1, data_wdsm$survey_weight)
  
  # Initialize match matrices
  matches_0 <- vector("list", n)  # Matches for estimating Y(0)
  matches_1 <- vector("list", n)  # Matches for estimating Y(1)
  
  # Find matches for treated units (to estimate Y(0))
  treated_idx <- which(A == 1)
  control_idx <- which(A == 0)
  
  cat("\nPerforming Double Score Matching (M =", M, ")...\n")
  
  for (i in treated_idx) {
    # Calculate distances to all control units
    distances <- apply(D0_std[control_idx, , drop = FALSE], 1, function(x) {
      sqrt(sum((D0_std[i, ] - x)^2))
    })
    
    # Find M nearest neighbors
    if (length(distances) >= M) {
      nearest <- control_idx[order(distances)[1:M]]
    } else {
      nearest <- control_idx[order(distances)]
    }
    
    matches_0[[i]] <- nearest
  }
  
  # Find matches for control units (to estimate Y(1))
  for (i in control_idx) {
    # Calculate distances to all treated units
    distances <- apply(D1_std[treated_idx, , drop = FALSE], 1, function(x) {
      sqrt(sum((D1_std[i, ] - x)^2))
    })
    
    # Find M nearest neighbors
    if (length(distances) >= M) {
      nearest <- treated_idx[order(distances)[1:M]]
    } else {
      nearest <- treated_idx[order(distances)]
    }
    
    matches_1[[i]] <- nearest
  }
  
  cat("Matching complete.\n")
  cat("Average match distance for Y(0):", 
      round(mean(sapply(matches_0[treated_idx], function(m) {
        if (!is.null(m)) mean(apply(D0_std[m, , drop = FALSE], 1, 
                                    function(x) sqrt(sum((D0_std[m[1], ] - x)^2))))
        else NA
      }), na.rm = TRUE), 4), "\n")
  
  return(list(
    matches_0 = matches_0,
    matches_1 = matches_1,
    D0 = D0,
    D1 = D1,
    D0_std = D0_std,
    D1_std = D1_std
  ))
}

# ==============================================================================
# PART 6: WDSM POINT ESTIMATION WITH WEIGHTED IMPUTATION
# ==============================================================================

calculate_wdsm_pate <- function(data_wdsm, matches) {
  Y <- data_wdsm$Y
  A <- data_wdsm$A
  w <- data_wdsm$survey_weight
  n <- data_wdsm$n
  
  # Initialize imputed potential outcomes
  Y_hat_0 <- Y_hat_1 <- rep(NA, n)
  
  # For treated units, use observed Y(1) and impute Y(0)
  treated_idx <- which(A == 1)
  for (i in treated_idx) {
    Y_hat_1[i] <- Y[i]  # Observed
    
    # Impute Y(0) using weighted average of matched controls
    matched_controls <- matches$matches_0[[i]]
    if (!is.null(matched_controls) && length(matched_controls) > 0) {
      matched_weights <- w[matched_controls]
      Y_hat_0[i] <- sum(matched_weights * Y[matched_controls]) / sum(matched_weights)
    }
  }
  
  # For control units, use observed Y(0) and impute Y(1)
  control_idx <- which(A == 0)
  for (i in control_idx) {
    Y_hat_0[i] <- Y[i]  # Observed
    
    # Impute Y(1) using weighted average of matched treated
    matched_treated <- matches$matches_1[[i]]
    if (!is.null(matched_treated) && length(matched_treated) > 0) {
      matched_weights <- w[matched_treated]
      Y_hat_1[i] <- sum(matched_weights * Y[matched_treated]) / sum(matched_weights)
    }
  }
  
  # Calculate PATE using Hajek estimator
  tau_wdsm <- sum(w * (Y_hat_1 - Y_hat_0), na.rm = TRUE) / sum(w)
  
  # Calculate treatment-specific means for diagnostics
  mu1_wdsm <- sum(w * Y_hat_1, na.rm = TRUE) / sum(w)
  mu0_wdsm <- sum(w * Y_hat_0, na.rm = TRUE) / sum(w)
  
  cat("\n=== WDSM PATE Estimation Results ===\n")
  cat("E[Y(1)]:", round(mu1_wdsm, 4), "\n")
  cat("E[Y(0)]:", round(mu0_wdsm, 4), "\n")
  cat("PATE (τ_WDSM):", round(tau_wdsm, 4), "\n")
  
  return(list(
    tau_wdsm = tau_wdsm,
    mu1_wdsm = mu1_wdsm,
    mu0_wdsm = mu0_wdsm,
    Y_hat_0 = Y_hat_0,
    Y_hat_1 = Y_hat_1
  ))
}

# ==============================================================================
# PART 7: MULTINOMIAL BOOTSTRAP FOR VARIANCE ESTIMATION
# ==============================================================================

wdsm_bootstrap_inference <- function(data_wdsm, B = 500, alpha = 0.05) {
  # Multinomial bootstrap for retrospective sampling (NHANES case)
  # This follows the theoretical development in WDSM paper
  
  n <- data_wdsm$n
  tau_boot <- numeric(B)
  
  cat("\n=== Starting Bootstrap Inference (B =", B, ") ===\n")
  
  for (b in 1:B) {
    if (b %% 50 == 0) cat("Bootstrap iteration:", b, "/", B, "\n")
    
    # Generate multinomial weights
    m_star <- rmultinom(1, n, rep(1/n, n))[, 1]
    
    # Create bootstrap weights = multinomial × survey weights
    w_boot <- m_star * data_wdsm$survey_weight
    
    # Re-estimate all components with bootstrap weights
    # ... (implement full bootstrap estimation pipeline)
    
    # Store bootstrap estimate
    # tau_boot[b] <- bootstrap_estimate
  }
  
  # Calculate confidence interval
  # ci_lower <- quantile(tau_boot, alpha/2)
  # ci_upper <- quantile(tau_boot, 1 - alpha/2)
  # se_boot <- sd(tau_boot)
  
  # Placeholder for now
  cat("Bootstrap inference to be implemented...\n")
  
  return(list(
    tau_boot = tau_boot,
    ci_lower = NA,
    ci_upper = NA,
    se = NA
  ))
}

# ==============================================================================
# PART 8: MAIN WDSM ANALYSIS FUNCTION
# ==============================================================================

run_wdsm_nhanes_analysis <- function() {
  cat("\n")
  cat("=" ,rep("=", 70), "\n", sep="")
  cat("    WDSM ANALYSIS FOR NHANES TELOMERE LENGTH DATA\n")
  cat("    Research Question: Race Effect on Telomere Length After SES Adjustment\n")
  cat("=" ,rep("=", 70), "\n\n", sep="")
  
  # Step 1: Prepare data
  cat("STEP 1: Loading and preparing NHANES data...\n")
  data_wdsm <- prepare_nhanes_for_wdsm()
  cat("Sample size: n =", data_wdsm$n, "\n")
  cat("Treated (Black):", data_wdsm$n_treated, "\n")
  cat("Control (White):", data_wdsm$n_control, "\n")
  
  # Step 2: Estimate propensity scores
  cat("\nSTEP 2: Estimating propensity scores with survey weights...\n")
  ps_results <- estimate_propensity_score_nhanes(data_wdsm)
  
  # Step 3: Estimate prognostic scores
  cat("\nSTEP 3: Estimating prognostic scores with survey weights...\n")
  prog_results <- estimate_prognostic_scores_nhanes(data_wdsm)
  
  # Step 4: Apply bias correction
  cat("\nSTEP 4: Applying polynomial sieve bias correction...\n")
  bc_results <- apply_polynomial_sieve_correction(
    data_wdsm, 
    ps_results$e_score,
    prog_results$psi0,
    prog_results$psi1
  )
  
  # Step 5: Perform matching (M=5)
  cat("\nSTEP 5: Performing double score matching (M = 5)...\n")
  match_results <- perform_double_score_matching(
    data_wdsm,
    ps_results$e_score,
    bc_results$mu0_bc,
    bc_results$mu1_bc,
    M = 5
  )
  
  # Step 6: Calculate PATE
  cat("\nSTEP 6: Calculating WDSM PATE estimate...\n")
  pate_results <- calculate_wdsm_pate(data_wdsm, match_results)
  
  # Step 7: Bootstrap inference
  cat("\nSTEP 7: Bootstrap inference for confidence intervals...\n")
  boot_results <- wdsm_bootstrap_inference(data_wdsm, B = 500)
  
  # Final results
  cat("\n")
  cat("=" ,rep("=", 70), "\n", sep="")
  cat("    FINAL WDSM RESULTS\n")
  cat("=" ,rep("=", 70), "\n", sep="")
  cat("\nPopulation Average Treatment Effect (PATE):\n")
  cat("  Point Estimate:", round(pate_results$tau_wdsm, 4), "\n")
  cat("  Standard Error:", round(boot_results$se, 4), "\n")
  cat("  95% CI: [", round(boot_results$ci_lower, 4), ", ", 
      round(boot_results$ci_upper, 4), "]\n", sep="")
  
  cat("\nInterpretation:\n")
  if (boot_results$ci_lower < 0 && boot_results$ci_upper > 0) {
    cat("  The racial difference in telomere length is not statistically\n")
    cat("  significant after adjusting for socioeconomic status.\n")
  } else {
    cat("  There remains a significant racial difference in telomere length\n")
    cat("  even after adjusting for socioeconomic status.\n")
  }
  
  return(list(
    data = data_wdsm,
    ps_results = ps_results,
    prog_results = prog_results,
    bc_results = bc_results,
    match_results = match_results,
    pate_results = pate_results,
    boot_results = boot_results
  ))
}

# ==============================================================================
# Execute Analysis
# ==============================================================================

# Uncomment to run:
# results <- run_wdsm_nhanes_analysis()

