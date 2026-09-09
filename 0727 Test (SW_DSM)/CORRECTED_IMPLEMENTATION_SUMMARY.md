# CORRECTED Poor Overlap Implementation Summary

## What Was Wrong

Based on examining the Good Overlap CORRECTED scripts, I found several critical issues in our previous implementation:

### 1. **Missing dsmatch Function Sourcing in Worker**
❌ **Previous**: Only sourced dsmatch files at top level
✅ **Fixed**: Now source ALL dsmatch files INSIDE the worker function (lines 78-91 of corrected script)

```R
# CRITICAL: Source dsmatch functions INSIDE the worker
dsmatch_files <- c(
  "dsmatch-master/R/bisect.R",
  "dsmatch-master/R/is.lp.R",
  "dsmatch-master/R/is.ps.R", 
  "dsmatch-master/R/is.pg.R",
  "dsmatch-master/R/estforboot_dsATE.R",
  "dsmatch-master/R/estforboot_psATE.R",
  "dsmatch-master/R/estforboot_pgATE.R",
  "dsmatch-master/R/estforboot_covATE.R",
  "dsmatch-master/R/dsmatchATE.R"
)

for (file in dsmatch_files) {
  source(file)
}
```

### 2. **Incorrect DSM Parameter Usage**
❌ **Previous**: Used non-existent `X.ps` parameter
✅ **Fixed**: Use `X` for PS model, `lp.pg` for PG model

```R
# CORRECT DSM implementation
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps,  # PS model uses X_ps (with/without interaction)
  A = A,
  method = "dsm",
  model.ps = "logit",  # Fit logit model on X
  model.pg = "linpred",  # Use linear predictors for PG
  lp.pg = X_pg,  # PG model uses X_pg (with/without interaction)
  M = M,
  ...
)
```

### 3. **Wrong PG Model Specification**
❌ **Previous**: Used `model.pg = "linpred"` for PG matching
✅ **Fixed**: Use `model.pg = "glm"` for PG matching

```R
# CORRECT PG matching
pg_result <- dsmatchATE(
  Y = Y,
  X = X_pg,
  A = A,
  method = "pg",
  model.pg = "glm",  # Linear model for continuous outcome
  M = M,
  ...
)
```

### 4. **Scenario-Specific X Matrix Construction**
✅ **Now Correctly Implemented**:

```R
# Create X matrices for PS and PG models based on scenario
if (use_interaction_ps) {
  X_ps <- cbind(X, X[,1] * X[,2])
  colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
} else {
  X_ps <- X
  colnames(X_ps) <- c("x1", "x2", "x3", "x4", "x5", "x6")
}

if (use_interaction_pg) {
  X_pg <- cbind(X, X[,1] * X[,2])
  colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6", "x1_x2")
} else {
  X_pg <- X
  colnames(X_pg) <- c("x1", "x2", "x3", "x4", "x5", "x6")
}
```

## Why Previous Jobs Failed

The unweighted methods (DSM, PG, PS) didn't produce results because:
1. **dsmatch functions weren't available in parallel workers** - This caused silent failures
2. **Parameter errors** - Using `X.ps` which doesn't exist in dsmatchATE
3. **Incorrect model specifications** - Wrong `model.pg` for PG matching

## Expected Results After Correction

### CorCor Scenario (Both Models Correct)
- **WDSM**: <1% bias, ~95% coverage
- **DSM**: ~1-2% bias, ~94-96% coverage
- **PG**: ~2-3% bias, ~93-95% coverage
- **PS Unweighted**: ~2-3% bias, ~93-95% coverage
- **PS Weighted**: ~1-2% bias, ~94-96% coverage

### Other Scenarios
- **MisCor**: PS-based methods degraded, PG-based methods still good
- **CorMis**: PS-based methods still good, PG-based methods degraded
- **MisMis**: All methods degraded

## Files Updated

1. **`compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED.R`** - Master corrected version based on Good Overlap structure
2. **Deployed to all 4 scenario folders** with scenario-specific settings
3. **New SLURM scripts** created for submission to tong account

## Ready to Submit

The corrected scripts are ready to submit with:
```bash
./submit_corrected_100rep_jobs_tong.sh
```

This will submit all 4 scenarios (CorCor, MisCor, CorMis, MisMis) to the tong account with:
- 20 cores
- 160GB total memory
- 100 replications
- M = 5 matches
- 200 bootstrap iterations

## Key Lesson Learned

The Good Overlap CORRECTED implementation shows the importance of:
1. **Sourcing functions inside parallel workers** (FORK clusters share memory but not loaded functions)
2. **Using correct parameter names** from dsmatchATE documentation
3. **Following the established pattern** from working implementations
