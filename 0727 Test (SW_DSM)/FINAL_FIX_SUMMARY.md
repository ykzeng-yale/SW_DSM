# FINAL Fix Summary for DSM Implementation

## The Issue
The user correctly pointed out that my previous "corrections" didn't properly handle the DSM implementation. The key insight from their example is that `dsmatchATE` for DSM needs to use:
- The `X` parameter for PS model covariates
- The `model.pg = "linpred"` with `lp.pg` parameter for PG model covariates

This allows truly independent specification of PS and PG models, which is essential for the misspecification scenarios.

## Final Implementation

### DSM (Double Score Matching)
```R
# Create separate design matrices
if (use_interaction_ps) {
  X_ps_dsm <- cbind(X, X[,1] * X[,2])
  colnames(X_ps_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
} else {
  X_ps_dsm <- X
  colnames(X_ps_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6")
}

if (use_interaction_pg) {
  X_pg_dsm <- cbind(X, X[,1] * X[,2])
  colnames(X_pg_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
} else {
  X_pg_dsm <- X
  colnames(X_pg_dsm) <- c("x1", "x2", "x3", "x4", "x5", "x6")
}

# Run DSM with independent specifications
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps_dsm,          # Use PS specification for X
  A = A,
  method = "dsm",
  model.ps = "logit",
  model.pg = "linpred",  # Use linear predictor for PG
  lp.pg = X_pg_dsm,      # Use PG specification via lp.pg
  M = M,
  ...
)
```

### PS Matching
```R
if (use_interaction_ps) {
  X_ps <- cbind(X, X[,1] * X[,2])
  colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
} else {
  X_ps <- X
  colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6")
}

ps_result <- dsmatchATE(
  Y = Y,
  X = X_ps,  # Use correct X for PS
  A = A,
  method = "ps",
  model.ps = "logit",
  M = M,
  ...
)
```

### PG Matching
```R
if (use_interaction_pg) {
  X_pg <- cbind(X, X[,1] * X[,2])
  colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
} else {
  X_pg <- X
  colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6")
}

pg_result <- dsmatchATE(
  Y = Y,
  X = X_pg,  # Use correct X for PG
  A = A,
  method = "pg",
  M = M,
  ...
)
```

## Scenario Specifications

| Scenario | PS Model | PG Model | use_interaction_ps | use_interaction_pg |
|----------|----------|----------|-------------------|-------------------|
| CorCor   | Has X1:X2 | Has X1:X2 | TRUE | TRUE |
| MisCor   | No X1:X2 | Has X1:X2 | FALSE | TRUE |
| CorMis   | Has X1:X2 | No X1:X2 | TRUE | FALSE |
| MisMis   | No X1:X2 | No X1:X2 | FALSE | FALSE |

## Key Points

1. **DSM** can handle PS and PG specifications independently by using:
   - `X` parameter for PS model
   - `model.pg = "linpred"` with `lp.pg` for PG model

2. **PS Matching** uses the `X` parameter with appropriate interaction specification

3. **PG Matching** uses the `X` parameter with appropriate interaction specification

4. **No model type changes** - always use `model.ps = "logit"`

## Files Updated

1. `compare_methods_pate_retrospective_mccleary_M5_100reps_FINAL.R` - Master final version
2. Deployed to all scenario folders with scenario-specific modifications
3. `submit_final_100rep_jobs.sh` - Job submission script

## Expected Results

With this final implementation:
- **CorCor scenario**: 
  - WDSM: <1% bias, ~95% coverage
  - DSM: ~1-2% bias, ~94-96% coverage
  - All methods should show good performance with correct specifications

- **Misspecification scenarios**: 
  - Appropriate degradation based on which model is misspecified
  - MisCor: PS misspecified, PG correct
  - CorMis: PS correct, PG misspecified  
  - MisMis: Both misspecified
