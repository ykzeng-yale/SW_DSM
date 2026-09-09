# Correct usage of dsmatch for model misspecification scenarios

# KEY INSIGHT: Model misspecification should ONLY affect the covariates,
# NOT the model type (logit vs linpred)

# For each scenario, create the correct dsmatch calls:

create_correct_dsmatch_code <- function(scenario) {
  
  cat("\n========================================\n")
  cat("Scenario:", scenario, "\n")
  cat("========================================\n\n")
  
  # Determine which models include interaction
  use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
  use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
  
  cat("PS includes X1:X2 interaction:", use_interaction_ps, "\n")
  cat("PGS includes X1:X2 interaction:", use_interaction_pg, "\n\n")
  
  # Create X matrices
  cat("# Create covariate matrices\n")
  cat("if (use_interaction_ps) {\n")
  cat("  X_ps <- cbind(X, X[,1] * X[,2])\n")
  cat("  colnames(X_ps) <- c('x1', 'x2', 'x3', 'x4', 'x5', 'x6', 'x1_x2')\n")
  cat("} else {\n")
  cat("  X_ps <- X\n")
  cat("  colnames(X_ps) <- c('x1', 'x2', 'x3', 'x4', 'x5', 'x6')\n")
  cat("}\n\n")
  
  cat("if (use_interaction_pg) {\n")
  cat("  X_pg <- cbind(X, X[,1] * X[,2])\n")
  cat("  colnames(X_pg) <- c('x1', 'x2', 'x3', 'x4', 'x5', 'x6', 'x1_x2')\n")
  cat("} else {\n")
  cat("  X_pg <- X\n")
  cat("  colnames(X_pg) <- c('x1', 'x2', 'x3', 'x4', 'x5', 'x6')\n")
  cat("}\n\n")
  
  # METHOD 1: Double Score Matching
  cat("# METHOD 1: Double Score Matching\n")
  cat("# DSM needs both PS and PG models\n")
  cat("# For DSM, we need to pass the full covariate matrix\n")
  cat("# The package will fit both PS and PG models internally\n\n")
  
  cat("# Create combined matrix for DSM\n")
  cat("# DSM will fit PS model: logit(P(A=1)) ~ X_dsm\n")
  cat("# DSM will fit PG model: E[Y|A=0] ~ X_dsm\n")
  cat("if (use_interaction_ps || use_interaction_pg) {\n")
  cat("  # If either model needs interaction, include it\n")
  cat("  X_dsm <- cbind(X, X[,1] * X[,2])\n")
  cat("  colnames(X_dsm) <- c('x1', 'x2', 'x3', 'x4', 'x5', 'x6', 'x1_x2')\n")
  cat("} else {\n")
  cat("  X_dsm <- X\n")
  cat("  colnames(X_dsm) <- c('x1', 'x2', 'x3', 'x4', 'x5', 'x6')\n")
  cat("}\n\n")
  
  cat("dsm_result <- dsmatchATE(\n")
  cat("  Y = Y,\n")
  cat("  X = X_dsm,  # DSM will use this for both PS and PG\n")
  cat("  A = A,\n")
  cat("  method = 'dsm',\n")
  cat("  model.ps = 'logit',  # ALWAYS logit for PS\n")
  cat("  model.pg = 'lm',     # Linear model for PG\n")
  cat("  cov.balance = FALSE,\n")
  cat("  varest = TRUE,\n")
  cat("  boots = B,\n")
  cat("  mc = FALSE,\n")
  cat("  ncpus = 1\n")
  cat(")\n\n")
  
  # METHOD 2: Prognostic Score Matching
  cat("# METHOD 2: Prognostic Score Matching\n")
  cat("pg_result <- dsmatchATE(\n")
  cat("  Y = Y,\n")
  cat("  X = X_pg,  # Use PG-specific matrix\n")
  cat("  A = A,\n")
  cat("  method = 'pg',\n")
  cat("  model.pg = 'lm',  # Linear model for PG\n")
  cat("  cov.balance = FALSE,\n")
  cat("  varest = TRUE,\n")
  cat("  boots = B,\n")
  cat("  mc = FALSE,\n")
  cat("  ncpus = 1\n")
  cat(")\n\n")
  
  # METHOD 3: Propensity Score Matching
  cat("# METHOD 3: Propensity Score Matching\n")
  cat("ps_result <- dsmatchATE(\n")
  cat("  Y = Y,\n")
  cat("  X = X_ps,  # Use PS-specific matrix\n")
  cat("  A = A,\n")
  cat("  method = 'ps',\n")
  cat("  model.ps = 'logit',  # ALWAYS logit for PS\n")
  cat("  cov.balance = FALSE,\n")
  cat("  varest = TRUE,\n")
  cat("  boots = B,\n")
  cat("  mc = FALSE,\n")
  cat("  ncpus = 1\n")
  cat(")\n\n")
}

# Generate correct code for each scenario
scenarios <- c("CorCor", "MisCor", "CorMis", "MisMis")
for (scenario in scenarios) {
  create_correct_dsmatch_code(scenario)
}

cat("\n========================================\n")
cat("KEY POINTS:\n")
cat("========================================\n")
cat("1. ALWAYS use model.ps = 'logit' for propensity scores\n")
cat("2. ALWAYS use model.pg = 'lm' for prognostic scores\n")
cat("3. NEVER use 'linpred' - that's for pre-computed linear predictors\n")
cat("4. Change ONLY the X matrix to include/exclude interaction\n")
cat("5. Do NOT use lp.ps or lp.pg parameters\n")


