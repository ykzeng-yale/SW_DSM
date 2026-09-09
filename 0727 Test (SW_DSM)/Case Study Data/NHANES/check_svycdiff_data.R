################################################################################
# Check svycdiff NHANES data structure
################################################################################

library(svycdiff)
data(NHANES)

cat("\n=== NHANES Data from svycdiff Package ===\n")
cat("Dimensions:", dim(NHANES), "\n")
cat("Sample size:", nrow(NHANES), "\n")

# Check treatment variable
cat("\nRACE_2CAT distribution:\n")
print(table(NHANES$RACE_2CAT, useNA = "ifany"))

# Check outcome
cat("\nTelomere length (non-missing):", sum(!is.na(NHANES$lTELOMEAN)), "\n")

# Check SES variables (12 variables as in Salerno)
ses_vars <- c('EDUC_3CAT', 'MARTL_3CAT', 'PIR_3CAT', 'EMPSTAT_4CAT', 'OCC_5CAT', 
              'HHSIZE_5CAT', 'HHINC_5CAT', 'HIQ_2CAT', 'WIC_2CAT', 'FDSEC_3CAT', 
              'HOD_4CAT', 'OWNHOME_2CAT')

cat("\n=== SES Variables (12) ===\n")
for (var in ses_vars) {
  if (var %in% names(NHANES)) {
    cat(sprintf("%-15s: %s, levels = %d\n", 
                var, class(NHANES[[var]]), 
                ifelse(is.factor(NHANES[[var]]), nlevels(NHANES[[var]]), NA)))
  } else {
    cat(sprintf("%-15s: NOT FOUND\n", var))
  }
}

# Check demographic variables
demo_vars <- c('AGE', 'SEX')
cat("\n=== Demographic Variables ===\n")
for (var in demo_vars) {
  if (var %in% names(NHANES)) {
    cat(sprintf("%-15s: %s\n", var, class(NHANES[[var]])))
  }
}

# Check blood composition variables
blood_vars <- c('LBXWBCSI', 'LBXLYPCT', 'LBXMOPCT', 'LBXNEPCT', 'LBXEOPCT', 'LBXBAPCT')
cat("\n=== Blood Composition Variables ===\n")
for (var in blood_vars) {
  if (var %in% names(NHANES)) {
    cat(sprintf("%-15s: %s\n", var, class(NHANES[[var]])))
  } else {
    cat(sprintf("%-15s: NOT FOUND\n", var))
  }
}

# Check survey weight
cat("\n=== Survey Weight ===\n")
cat("WTMEC4YR range:", range(NHANES$WTMEC4YR, na.rm = TRUE), "\n")
cat("iWTMEC4YR range:", range(NHANES$iWTMEC4YR, na.rm = TRUE), "\n")

# Count total covariates when expanded to dummy variables
cat("\n=== Covariate Expansion ===\n")

# Create model matrix to see actual number of parameters
# PS model: 12 SES variables
ps_formula <- as.formula(paste("RACE_2CAT ~", paste(ses_vars, collapse = " + ")))
X_ps <- model.matrix(ps_formula, data = NHANES)
cat("PS model matrix dimensions:", dim(X_ps), "\n")
cat("PS model parameters (including intercept):", ncol(X_ps), "\n")

# PG model: 12 SES + 2 demo + 6 blood
all_covars <- c(ses_vars, demo_vars, blood_vars)
pg_formula <- as.formula(paste("lTELOMEAN ~", paste(all_covars[all_covars %in% names(NHANES)], 
                                                     collapse = " + ")))
X_pg <- model.matrix(pg_formula, data = NHANES)
cat("PG model matrix dimensions:", dim(X_pg), "\n")
cat("PG model parameters (including intercept):", ncol(X_pg), "\n")

# Check if there are missing values
cat("\n=== Missing Values ===\n")
complete_cases <- complete.cases(NHANES[, c("RACE_2CAT", "lTELOMEAN", ses_vars, 
                                             demo_vars, blood_vars[blood_vars %in% names(NHANES)])])
cat("Complete cases:", sum(complete_cases), "out of", nrow(NHANES), "\n")

# Try a simple model
cat("\n=== Testing Simple GLM ===\n")
simple_model <- glm(RACE_2CAT ~ EDUC_3CAT + PIR_3CAT, 
                    data = NHANES, 
                    family = binomial,
                    weights = WTMEC4YR)
cat("Simple model converged:", simple_model$converged, "\n")

# Try full PS model
cat("\n=== Testing Full PS Model ===\n")
suppressWarnings({
  full_ps_model <- glm(ps_formula, 
                       data = NHANES, 
                       family = binomial,
                       weights = WTMEC4YR,
                       control = glm.control(maxit = 100, epsilon = 1e-6))
})
cat("Full PS model converged:", full_ps_model$converged, "\n")
if (!full_ps_model$converged) {
  cat("Warning: PS model did not converge\n")
}



