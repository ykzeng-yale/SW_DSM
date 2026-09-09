# CORRECT Fix Summary for Poor Overlap Analysis

## Problem Identified
The user correctly identified that I made a serious error in the previous "fix". I incorrectly changed model types (from `logit` to `linpred`) when I should have ONLY been changing whether the X1:X2 interaction term is included in the covariate matrices.

## Incorrect Fix (What I Did Wrong)
- Changed `model.ps` from "logit" to "linpred" 
- Changed matching approach unnecessarily
- Modified model types when only covariate specification should change

## Correct Fix (What Should Be Done)
The ONLY thing that should change across scenarios is whether X1:X2 interaction is included in the covariates:

### For DSM (Double Score Matching):
- Always use `method = "dsm"` with `model.ps = "logit"`
- Use **separate** covariate matrices for PS and PG models:
  - `X.ps`: Covariates for PS model (with/without X1:X2 based on `use_interaction_ps`)
  - `X`: Covariates for PG/outcome model (with/without X1:X2 based on `use_interaction_pg`)

### For PS Matching:
- Always use `method = "ps"` with `model.ps = "logit"` 
- Only change `X.ps` parameter (with/without X1:X2 based on `use_interaction_ps`)

### For PG Matching:
- Always use `method = "pg"`
- Only change `X` parameter (with/without X1:X2 based on `use_interaction_pg`)

## Scenario Specifications

| Scenario | PS Model | PG Model | use_interaction_ps | use_interaction_pg |
|----------|----------|----------|-------------------|-------------------|
| CorCor   | Correct (has X1:X2) | Correct (has X1:X2) | TRUE | TRUE |
| MisCor   | Misspecified (no X1:X2) | Correct (has X1:X2) | FALSE | TRUE |
| CorMis   | Correct (has X1:X2) | Misspecified (no X1:X2) | TRUE | FALSE |
| MisMis   | Misspecified (no X1:X2) | Misspecified (no X1:X2) | FALSE | FALSE |

## Key Implementation Details

```R
# CORRECT implementation for DSM
X_for_ps <- if (use_interaction_ps) {
  cbind(X, X[,1] * X[,2])  # Include interaction for PS
} else {
  X  # No interaction for PS
}

X_for_pg <- if (use_interaction_pg) {
  cbind(X, X[,1] * X[,2])  # Include interaction for PG
} else {
  X  # No interaction for PG
}

dsm_result <- dsmatchATE(
  Y = Y,
  X = X_for_pg,        # X for outcome model (PG)
  A = A,
  method = "dsm",
  model.ps = "logit",  # Always use logit
  X.ps = X_for_ps,     # Separate X for PS model
  M = M,
  ...
)
```

## Files Updated
1. `compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECT.R` - Master corrected version
2. Deployed to all scenario folders with appropriate scenario-specific modifications

## Expected Results After Correction
- **CorCor scenario**: 
  - WDSM: <1% bias, ~95% coverage
  - DSM: ~1-2% bias, ~94-96% coverage
  - All methods should show good performance
- **Other scenarios**: Appropriate degradation based on model misspecification
