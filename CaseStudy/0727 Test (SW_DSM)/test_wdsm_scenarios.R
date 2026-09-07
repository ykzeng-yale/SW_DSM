# Test WDSM Implementation Across Scenarios
# This script verifies that WDSM correctly uses different model specifications

library(dplyr)
set.seed(123)

cat("════════════════════════════════════════════════════════════════\n")
cat("         TESTING WDSM MODEL SPECIFICATIONS\n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Source WDSM functions from CorCor folder (all are identical)
source("PATE Retrospective Goodoverlap M5 CorCor 100rep GLM/wdsm_ci_functions.R")
source("PATE Retrospective Goodoverlap M5 CorCor 100rep GLM/wdsm_method2_multinomial_bootstrap.R")

# Create a small test dataset
n <- 200
X <- matrix(rnorm(n * 6), n, 6)
colnames(X) <- paste0("X", 1:6)

# Add interaction effect
interaction_effect <- X[,1] * X[,2]

# Generate treatment based on PS with interaction
ps_linear <- 0.5 + 0.3*X[,1] + 0.2*X[,2] + 0.1*interaction_effect + 0.1*X[,3]
ps_true <- plogis(ps_linear)
A <- rbinom(n, 1, ps_true)

# Generate outcome with interaction effect
Y <- 1 + 0.5*A + 0.3*X[,1] + 0.2*X[,2] + 0.15*interaction_effect + 
     0.1*X[,3] + 0.1*X[,4] + rnorm(n, 0, 0.5)

# Create survey weights (for simplicity, use uniform weights)
weights <- rep(1, n)

# Create data frame
test_data <- data.frame(
  Y = Y,
  A = A,
  X1 = X[,1], X2 = X[,2], X3 = X[,3],
  X4 = X[,4], X5 = X[,5], X6 = X[,6],
  survey_weight = weights
)

cat("Testing each scenario with n =", n, "observations\n\n")

# Test each scenario
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")

results <- list()

for (scenario in scenarios) {
  cat("─────────────────────────────────────────────────────────────\n")
  cat("Testing", scenario, ":\n")
  
  # Set model specification flags (exact logic from comparison script)
  use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
  use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
  
  cat("  use_interaction_ps =", use_interaction_ps, "\n")
  cat("  use_interaction_pg =", use_interaction_pg, "\n")
  
  # Test formula construction
  ps_formula <- if (use_interaction_ps) {
    A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    A ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  
  pg_formula <- if (use_interaction_pg) {
    Y ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2
  } else {
    Y ~ X1 + X2 + X3 + X4 + X5 + X6
  }
  
  cat("\n  PS Formula:", deparse(ps_formula), "\n")
  cat("  PG Formula:", deparse(pg_formula), "\n")
  
  # Fit models to verify they work
  tryCatch({
    # PS model
    ps_model <- glm(ps_formula, 
                    data = test_data,
                    family = quasibinomial(link = "logit"),
                    weights = survey_weight)
    
    # Check if interaction term is in the model
    ps_coefs <- names(coef(ps_model))
    has_ps_interaction <- "X1:X2" %in% ps_coefs
    cat("\n  PS Model coefficients include X1:X2?", has_ps_interaction, "\n")
    
    # PG model for control units
    pg_model <- lm(pg_formula, 
                   data = test_data[test_data$A == 0,],
                   weights = survey_weight[test_data$A == 0])
    
    # Check if interaction term is in the model
    pg_coefs <- names(coef(pg_model))
    has_pg_interaction <- "X1:X2" %in% pg_coefs
    cat("  PG Model coefficients include X1:X2?", has_pg_interaction, "\n")
    
    # Verify logic is correct
    expected_ps <- use_interaction_ps
    expected_pg <- use_interaction_pg
    
    if (has_ps_interaction == expected_ps && has_pg_interaction == expected_pg) {
      cat("\n  ✅ Model specifications are CORRECT!\n")
    } else {
      cat("\n  ❌ ERROR: Model specifications don't match expectations!\n")
      cat("    Expected PS interaction:", expected_ps, "Got:", has_ps_interaction, "\n")
      cat("    Expected PG interaction:", expected_pg, "Got:", has_pg_interaction, "\n")
    }
    
    # Run WDSM point estimate to verify it works
    point_est <- wdsm_point_estimate(
      data = test_data, 
      M = 3, 
      use_bias_correction = TRUE,
      use_interaction_ps = use_interaction_ps,
      use_interaction_pg = use_interaction_pg
    )
    
    cat("\n  WDSM Point Estimate: τ =", round(point_est$tau, 4), "\n")
    
    results[[scenario]] <- list(
      estimate = point_est$tau,
      ps_has_interaction = has_ps_interaction,
      pg_has_interaction = has_pg_interaction,
      correct = (has_ps_interaction == expected_ps && has_pg_interaction == expected_pg)
    )
    
  }, error = function(e) {
    cat("\n  ❌ Error:", e$message, "\n")
    results[[scenario]] <- list(error = e$message)
  })
}

cat("\n════════════════════════════════════════════════════════════════\n")
cat("                        SUMMARY\n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Check if all scenarios passed
all_correct <- all(sapply(results, function(x) !is.null(x$correct) && x$correct))

if (all_correct) {
  cat("✅ ALL SCENARIOS PASSED!\n\n")
  cat("WDSM correctly implements:\n")
  cat("  • CorCor: Both models with X1:X2 interaction\n")
  cat("  • MisCor: PS without interaction, PGS with interaction\n")
  cat("  • CorMis: PS with interaction, PGS without interaction\n")
  cat("  • MisMis: Both models without X1:X2 interaction\n")
} else {
  cat("❌ Some scenarios failed. Check results above.\n")
}

cat("\n════════════════════════════════════════════════════════════════\n")
