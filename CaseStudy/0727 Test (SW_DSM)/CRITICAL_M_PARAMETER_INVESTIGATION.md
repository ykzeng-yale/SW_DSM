# CRITICAL INVESTIGATION: M Parameter in dsmatchATE

## Issue Identified

The `dsmatchATE` function signature is:
```R
dsmatchATE = function(Y, X, A, method = "dsm",
  model.ps = "other", ps = NULL, lp.ps = NULL,
  model.pg = "other", pg = NULL, lp.pg = NULL,
  cov.balance = F, varest = F, boots = 100, mc = F, ncpus = 4)
```

**There is NO `M` parameter in dsmatchATE!**

## What We've Been Doing

### Poor Overlap Scripts (INCORRECT)
```R
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps,
  A = A,
  method = "dsm",
  model.ps = "logit",
  model.pg = "linpred",
  lp.pg = X_pg,
  M = M,  # ❌ THIS PARAMETER DOESN'T EXIST!
  cov.balance = FALSE,
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)
```

### Good Overlap CORRECTED Scripts (CORRECT)
```R
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps,
  A = A,
  method = "dsm",
  model.ps = "logit",
  model.pg = "linpred",
  lp.pg = X_pg,
  cov.balance = FALSE,  # ✅ NO M PARAMETER
  varest = TRUE,
  boots = B,
  mc = FALSE,
  ncpus = 1
)
```

## Impact Assessment

1. **Currently Running Jobs**: All 4 CORRECTED jobs (57757185, 57757206, 57757210, 57757214) have the invalid `M = M` parameter
2. **What happens**: R will likely ignore the extra parameter (it's not in the function signature)
3. **Actual matching**: dsmatchATE probably does 1:1 matching by default

## Parameters That ARE Correct

✅ **Y** - Outcome variable  
✅ **A** - Treatment variable (0/1)  
✅ **boots = B** - Bootstrap iterations (200)  
✅ **X** matrices - Correctly constructed based on scenario  
✅ **model.ps = "logit"** - For PS models  
✅ **model.pg = "glm"/"linpred"** - For PG models  

## Conclusion

While the M parameter is invalid, it's likely being silently ignored by R, so the jobs should still run. However, we're not actually varying the number of matches as intended - all methods are probably doing 1:1 matching.

The Good Overlap CORRECTED scripts don't have this error, which is why they work properly.
