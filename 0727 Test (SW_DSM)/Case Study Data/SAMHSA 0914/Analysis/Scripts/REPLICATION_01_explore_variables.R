#!/usr/bin/env Rscript

#' =============================================================================
#' Script: REPLICATION_01_explore_variables.R
#' Purpose: Explore NSDUH 2023 variables for replication studies
#'          - Treatment variables
#'          - SUD indicators
#'          - Mental health variables
#'          - Demographics
#' Date: October 22, 2025
#' =============================================================================

cat("\n=============================================================\n")
cat("EXPLORING NSDUH 2023 VARIABLES FOR REPLICATION\n")
cat("=============================================================\n")

# Load data
load("Data & Doc/NSDUH_2023.Rdata")

cat("\n--- Dataset Loaded ---\n")
cat("Dimensions:", dim(data), "\n")
cat("Total variables:", ncol(data), "\n\n")

# =============================================================================
# 1. TREATMENT VARIABLES
# =============================================================================

cat("=== 1. TREATMENT VARIABLES ===\n\n")

# Search for substance use treatment variables
cat("Searching for substance use treatment variables...\n")
treat_patterns <- c("TXYR", "TXEV", "TXLT", "TRTY", "ANYTR", "TXYRTMT",
                    "TXNDYR", "RXOTCYR", "RXILYR")

treat_vars <- unique(unlist(lapply(treat_patterns, function(p) {
  grep(p, names(data), value = TRUE, ignore.case = TRUE)
})))

if(length(treat_vars) > 0) {
  cat("Found", length(treat_vars), "treatment-related variables:\n")
  for(v in treat_vars) {
    cat("  -", v, "\n")
  }
} else {
  cat("No direct treatment variables found with common patterns\n")
}

# Search more broadly
cat("\nSearching for alcohol/drug treatment section...\n")
adtx_vars <- names(data)[grepl("^(ADTX|ALCTX|DRGTX|IRSUTX|TXSU)", names(data))]
if(length(adtx_vars) > 0) {
  cat("Found", length(adtx_vars), "AD treatment variables:\n")
  for(v in head(adtx_vars, 20)) {
    cat("  -", v, "\n")
  }
}

# =============================================================================
# 2. SUD INDICATORS
# =============================================================================

cat("\n=== 2. SUD INDICATORS ===\n\n")

# Any illicit drug SUD
cat("Looking for any illicit drug SUD indicator...\n")
sud_any_vars <- names(data)[grepl("^(IRPY.*ANY|SUDANY|DGSUDANY)", names(data))]
if(length(sud_any_vars) > 0) {
  cat("Found SUD 'any' variables:\n")
  for(v in sud_any_vars) {
    cat("  -", v, "\n")
    # Check prevalence
    if(v %in% names(data)) {
      val <- data[[v]]
      if(is.numeric(val)) {
        n_sud <- sum(val == 1, na.rm = TRUE)
        pct <- round(100 * n_sud / sum(!is.na(val)), 2)
        cat("    Prevalence (unweighted):", pct, "% (N =", n_sud, ")\n")
      }
    }
  }
}

# Substance-specific SUDs
cat("\nSubstance-specific SUD variables:\n")
sud_specific <- c("IRPYUD5MRJ", "IRPYUD5COC", "IRPYUD5HER", "IRPYUD5HAL",
                  "IRPYUD5INH", "IRPYUD5MTH")
for(v in sud_specific) {
  if(v %in% names(data)) {
    val <- data[[v]]
    n_sud <- sum(val == 1, na.rm = TRUE)
    pct <- round(100 * n_sud / sum(!is.na(val)), 2)
    cat("  -", v, ":", pct, "% (N =", n_sud, ")\n")
  } else {
    cat("  -", v, ": NOT FOUND\n")
  }
}

# Prescription drug SUDs
cat("\nPrescription drug SUD variables:\n")
rx_sud <- c("SEVYRPNRANY", "SEVYRTRQANY", "SEVYRSTMANY", "SEVYRSEDANY")
for(v in rx_sud) {
  if(v %in% names(data)) {
    val <- data[[v]]
    n_sud <- sum(val == 1, na.rm = TRUE)
    pct <- round(100 * n_sud / sum(!is.na(val)), 2)
    cat("  -", v, ":", pct, "% (N =", n_sud, ")\n")
  } else {
    cat("  -", v, ": NOT FOUND\n")
  }
}

# Alcohol SUD
cat("\nAlcohol SUD:\n")
alc_sud_vars <- names(data)[grepl("^(IRPYALC|ALCUD|SEVYRALC)", names(data))]
if(length(alc_sud_vars) > 0) {
  for(v in head(alc_sud_vars, 5)) {
    if(v %in% names(data)) {
      val <- data[[v]]
      if(is.numeric(val)) {
        n_sud <- sum(val == 1, na.rm = TRUE)
        pct <- round(100 * n_sud / sum(!is.na(val)), 2)
        cat("  -", v, ":", pct, "% (N =", n_sud, ")\n")
      }
    }
  }
}

# =============================================================================
# 3. MENTAL HEALTH VARIABLES
# =============================================================================

cat("\n=== 3. MENTAL HEALTH VARIABLES ===\n\n")

# AMI/SMI
cat("Mental Illness Indicators:\n")
ami_smi_vars <- c("AMIYR", "AMIPY", "SMIYR", "SMIPY", "AMI2YR", "AMI2PY")
for(v in ami_smi_vars) {
  if(v %in% names(data)) {
    val <- data[[v]]
    n_ami <- sum(val == 1, na.rm = TRUE)
    pct <- round(100 * n_ami / sum(!is.na(val)), 2)
    cat("  -", v, ":", pct, "% (N =", n_ami, ")\n")
  } else {
    cat("  -", v, ": NOT FOUND\n")
  }
}

# MDE (Major Depressive Episode)
cat("\nMajor Depressive Episode:\n")
mde_vars <- c("DSMDEPYR", "DSMDEPPY", "MDEPY", "MDEYR")
for(v in mde_vars) {
  if(v %in% names(data)) {
    val <- data[[v]]
    if(is.numeric(val)) {
      n_mde <- sum(val == 1, na.rm = TRUE)
      pct <- round(100 * n_mde / sum(!is.na(val)), 2)
      cat("  -", v, ":", pct, "% (N =", n_mde, ")\n")
    }
  } else {
    cat("  -", v, ": NOT FOUND\n")
  }
}

# Mental health treatment
cat("\nMental Health Treatment:\n")
mh_tx_vars <- names(data)[grepl("^(MHTX|AMHTX|SMHTX|MHSVC)", names(data))]
if(length(mh_tx_vars) > 0) {
  for(v in head(mh_tx_vars, 10)) {
    if(v %in% names(data)) {
      val <- data[[v]]
      if(is.numeric(val)) {
        n_tx <- sum(val == 1, na.rm = TRUE)
        pct <- round(100 * n_tx / sum(!is.na(val)), 2)
        cat("  -", v, ":", pct, "% (N =", n_tx, ")\n")
      }
    }
  }
}

# =============================================================================
# 4. DEMOGRAPHICS
# =============================================================================

cat("\n=== 4. DEMOGRAPHICS ===\n\n")

# Age
cat("Age Variables:\n")
age_vars <- c("AGE2", "AGE3", "CATAGE", "CATAG2", "CATAG3", "CATAG6", "CATAG7")
for(v in age_vars) {
  if(v %in% names(data)) {
    val <- data[[v]]
    cat("  -", v, ": Range", min(val, na.rm=TRUE), "to", max(val, na.rm=TRUE), 
        ", N categories:", length(unique(val[!is.na(val)])), "\n")
  }
}

# Key demographics
cat("\nKey Demographics:\n")
demo_vars <- c("IRSEX", "NEWRACE2", "IRMARIT", "IREDUHIGHST2", "IRFAMIN3", "IRINSUR4")
for(v in demo_vars) {
  if(v %in% names(data)) {
    val <- data[[v]]
    cats <- table(val, useNA = "ifany")
    cat("  -", v, ":\n")
    print(cats)
    cat("\n")
  }
}

# =============================================================================
# 5. CREATE COMPOSITE ANY SUD INDICATOR FOR ADULTS
# =============================================================================

cat("\n=== 5. CREATING COMPOSITE SUD INDICATOR ===\n\n")

# Define adults (18+)
adults <- data$CATAGE >= 2  # CATAGE=2 is 18+

cat("Adults 18+ (CATAGE >= 2):", sum(adults, na.rm = TRUE), "\n")

# Try to find or create any SUD indicator
# Common approach: Any illicit drug OR prescription drug misuse disorder

if("IRPYUD5MRJ" %in% names(data)) {
  # Create composite SUD
  sud_components <- c(
    # Illicit drugs
    "IRPYUD5MRJ", "IRPYUD5COC", "IRPYUD5HER", "IRPYUD5HAL",
    "IRPYUD5INH", "IRPYUD5MTH",
    # Prescription drugs
    "SEVYRPNRANY", "SEVYRTRQANY", "SEVYRSTMANY", "SEVYRSEDANY"
  )
  
  # Check which exist
  existing_components <- sud_components[sud_components %in% names(data)]
  cat("\nFound", length(existing_components), "SUD components:\n")
  for(v in existing_components) {
    cat("  -", v, "\n")
  }
  
  # Create any SUD indicator
  any_sud <- rep(0, nrow(data))
  for(v in existing_components) {
    any_sud[data[[v]] == 1 & !is.na(data[[v]])] <- 1
  }
  
  # Add alcohol SUD if available
  if("IRALCUD" %in% names(data)) {
    any_sud[data$IRALCUD == 1 & !is.na(data$IRALCUD)] <- 1
    cat("  - IRALCUD (added)\n")
  }
  
  # Calculate prevalence
  n_any_sud <- sum(any_sud == 1)
  pct_any_sud <- round(100 * n_any_sud / length(any_sud), 2)
  
  # Among adults
  n_adult_sud <- sum(any_sud[adults] == 1, na.rm = TRUE)
  pct_adult_sud <- round(100 * n_adult_sud / sum(adults, na.rm = TRUE), 2)
  
  cat("\nAny SUD (composite):\n")
  cat("  Total population:", pct_any_sud, "% (N =", n_any_sud, ")\n")
  cat("  Adults 18+:", pct_adult_sud, "% (N =", n_adult_sud, ")\n")
  
  # Weighted prevalence
  w <- data$ANALWT2_C
  w_any_sud <- sum(w[any_sud == 1], na.rm = TRUE)
  w_total <- sum(w, na.rm = TRUE)
  pct_weighted <- round(100 * w_any_sud / w_total, 2)
  
  w_adult_sud <- sum(w[adults & any_sud == 1], na.rm = TRUE)
  w_adult_total <- sum(w[adults], na.rm = TRUE)
  pct_adult_weighted <- round(100 * w_adult_sud / w_adult_total, 2)
  
  cat("\nWeighted prevalence:\n")
  cat("  Total population:", pct_weighted, "%\n")
  cat("  Adults 18+:", pct_adult_weighted, "%\n")
  
} else {
  cat("Cannot create composite SUD - missing key variables\n")
}

# =============================================================================
# 6. SAVE SUMMARY
# =============================================================================

cat("\n=== 6. SAVING VARIABLE EXPLORATION SUMMARY ===\n\n")

exploration_summary <- list(
  dataset_info = list(
    n_rows = nrow(data),
    n_vars = ncol(data),
    n_adults_18plus = sum(adults, na.rm = TRUE)
  ),
  treatment_vars = treat_vars,
  sud_vars = existing_components,
  ami_smi_vars = ami_smi_vars[ami_smi_vars %in% names(data)],
  mh_tx_vars = mh_tx_vars,
  demographics = demo_vars
)

saveRDS(exploration_summary, 
        "Analysis/Results/replication_01_variable_exploration.rds")

cat("Summary saved to: Analysis/Results/replication_01_variable_exploration.rds\n")

cat("\n=============================================================\n")
cat("VARIABLE EXPLORATION COMPLETE\n")
cat("=============================================================\n\n")

cat("NEXT STEPS:\n")
cat("1. Review codebook to understand exact variable definitions\n")
cat("2. Map variables to replication study requirements\n")
cat("3. Create analytic dataset for each replication\n\n")



