# Complete Fix Summary - Model Misspecification Scripts

## Critical Errors Found and Fixed

### 1. ❌ **WRONG: Model Type Confusion**
I incorrectly used `model.ps = "linpred"` thinking it would handle the interaction term.
- `"linpred"` means use PRE-COMPUTED linear predictors
- This completely changed the model type, not just the covariates!

### 2. ❌ **WRONG: DSM Using Same Covariates**
DSM was using the same covariate matrix for both PS and PG models.
- This meant DSM couldn't have different misspecifications for PS vs PG
- For MisCor: Both models would incorrectly exclude interaction
- For CorMis: Both models would incorrectly include interaction

## ✅ Correct Implementation (Now Fixed)

### Model Types - ALWAYS Fixed:
```r
# For Propensity Score models:
model.ps = "logit"  # ALWAYS logit, regardless of covariates

# For Prognostic Score standalone:
model.pg = "glm"    # Linear model for continuous outcome

# For DSM's PG component:
model.pg = "linpred"  # Use with lp.pg parameter
```

### DSM - Separate Covariate Matrices:
```r
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps,        # PS model uses X_ps
  A = A,
  method = "dsm",
  model.ps = "logit",
  model.pg = "linpred",  
  lp.pg = X_pg,    # PG model uses X_pg (SEPARATE!)
  ...
)
```

### How Each Scenario Works:

| Scenario | PS Model | PG Model | X_ps Contains X1:X2? | X_pg Contains X1:X2? |
|----------|----------|----------|---------------------|---------------------|
| **CorCor** | Correct | Correct | ✅ Yes | ✅ Yes |
| **MisCor** | Misspecified | Correct | ❌ No | ✅ Yes |
| **CorMis** | Correct | Misspecified | ✅ Yes | ❌ No |
| **MisMis** | Misspecified | Misspecified | ❌ No | ❌ No |

## Example for MisCor Scenario:
```r
# MisCor: PS misspecified (no X1:X2), PG correct (with X1:X2)
use_interaction_ps <- FALSE  # PS excludes interaction
use_interaction_pg <- TRUE   # PG includes interaction

# Create matrices
X_ps <- X  # Just X1-X6, no interaction
X_pg <- cbind(X, X[,1] * X[,2])  # X1-X6 plus X1:X2

# DSM can now use different covariates!
dsm_result <- dsmatchATE(
  X = X_ps,        # PS fitted on X without interaction (misspecified)
  lp.pg = X_pg,    # PG fitted on X with interaction (correct)
  ...
)
```

## Status

All 4 scripts have been corrected and are ready for submission:
- ✅ `PATE Retrospective Goodoverlap M5 CorCor 1000rep CORRECTED GLM/`
- ✅ `PATE Retrospective Goodoverlap M5 MisCor 1000rep CORRECTED GLM/`
- ✅ `PATE Retrospective Goodoverlap M5 CorMis 1000rep CORRECTED GLM/`
- ✅ `PATE Retrospective Goodoverlap M5 MisMis 1000rep CORRECTED GLM/`

## Key Takeaway

Model misspecification is controlled by **which covariates are included**, NOT by changing model types:
- Propensity Score: Always `logit(P(A=1|X))`
- Prognostic Score: Always `E[Y|X,A=0]` with linear model
- Misspecification: Include/exclude X1:X2 interaction term in X matrix


