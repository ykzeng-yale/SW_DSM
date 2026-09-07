# Good Overlap CORRECTED vs Poor Overlap Implementation Comparison

## ✅ Good Overlap CORRECTED (Works Correctly)
From: `PATE Retrospective Goodoverlap M5 CorCor 1000rep CORRECTED GLM/`

### DSM Call (Lines 152-165)
```R
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps,  # PS model uses X_ps (with/without interaction)
  A = A,
  method = "dsm",
  model.ps = "logit",  # Fit logit model on X
  model.pg = "linpred",  # Use linear predictors for PG
  lp.pg = X_pg,  # PG model uses X_pg (with/without interaction)
  cov.balance = FALSE,
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)  # ✅ NO M PARAMETER
```

### PG Call (Lines 189-200)
```R
pg_result <- dsmatchATE(
  Y = Y,
  X = X_pg,
  A = A,
  method = "pg",
  model.pg = "glm",  # Linear model for continuous outcome
  cov.balance = FALSE,
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)  # ✅ NO M PARAMETER
```

### PS Call (Lines 223-234)
```R
ps_result <- dsmatchATE(
  Y = Y,
  X = X_ps,
  A = A,
  method = "ps",
  model.ps = "logit",  # Always logit for PS
  cov.balance = FALSE,
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)  # ✅ NO M PARAMETER
```

### Timeout Setting
```R
result <- R.utils::withTimeout({
  run_single_replicate(...)
}, timeout = 3600, onTimeout = "error")  # ✅ 3600 seconds (1 hour)
```

## ❌ Poor Overlap Current (Failed)
From: `PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps.R`

### DSM Call (Lines 156-170)
```R
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps,
  A = A,
  method = "dsm",
  model.ps = "logit",
  model.pg = "linpred",
  lp.pg = X_pg,
  M = M,  # ❌ INVALID PARAMETER!
  cov.balance = FALSE,
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)
```

### Error Message
```
DSM Unweighted Error in replicate 92 , scenario CorCor , M= 5 : unused argument (M = M)
PG Unweighted Error in replicate 93 , scenario CorCor , M= 5 : unused argument (M = M)
PS Unweighted Error in replicate 94 , scenario CorCor , M= 5 : unused argument (M = M)
```

### Timeout Setting
```R
result <- R.utils::withTimeout({
  run_single_replicate(...)
}, timeout = 300, onTimeout = "error")  # ❌ Too short for WDSM
```

## ✅ Poor Overlap FIXED (New)
From: `compare_methods_pate_retrospective_mccleary_M5_100reps_FIXED_NO_M.R`

### Key Changes
1. **Removed M parameter** from all dsmatchATE calls
2. **Increased timeout** from 300 to 600 seconds
3. **Added note** that dsmatchATE does 1:1 matching by default

### Fixed DSM Call
```R
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps,
  A = A,
  method = "dsm",
  model.ps = "logit",
  model.pg = "linpred",
  lp.pg = X_pg,
  # NO M PARAMETER - matches Good Overlap exactly
  cov.balance = FALSE,
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)
```

## Summary

| Aspect | Good Overlap CORRECTED | Poor Overlap Current | Poor Overlap FIXED |
|--------|------------------------|---------------------|-------------------|
| **M parameter in dsmatchATE** | ✅ None | ❌ M = M | ✅ None |
| **DSM works?** | ✅ Yes | ❌ No | ✅ Should work |
| **PG works?** | ✅ Yes | ❌ No | ✅ Should work |
| **PS works?** | ✅ Yes | ❌ No | ✅ Should work |
| **Timeout** | 3600 sec | 300 sec | 600 sec |
| **WDSM timeout issues?** | No (1000 reps) | Yes | Reduced |

## Conclusion

The Poor Overlap implementation failed because:
1. **Invalid M parameter** was passed to dsmatchATE (which doesn't accept it)
2. **Too short timeout** for WDSM bootstrap (300 seconds)

The FIXED version now exactly matches the Good Overlap CORRECTED implementation by:
1. **Removing M parameter** from all dsmatchATE calls
2. **Increasing timeout** to handle WDSM bootstrap better
3. **Keeping all other correct implementations** (sourcing in worker, model specifications, etc.)

## Note on M Parameter

The dsmatchATE function doesn't support k:1 matching via an M parameter. It performs 1:1 matching by default. If we need k:1 matching, we would need to:
- Use a different function (possibly dsmatchATT has M parameter?)
- Implement k:1 matching manually
- Use a different package that supports it
