# CRITICAL FIX: Use 1:1 Matching for Unweighted Methods

## The Problem Was:

We were forcing **M=5** (1:5 matching) on ALL methods including unweighted DSM/PS/PG.

With multi-stage sampling (n=5000):
- ~1600 treated units
- ~3400 control units
- Ratio: 2:1

For M=5 matching:
- Need: 1600 × 5 = 8000 matches
- Have: 3400 controls
- **MATHEMATICALLY IMPOSSIBLE!**

## The Fix:

### Unweighted Methods (DSM, PS, PG from dsmatch):
```r
# BEFORE:
dsmatchATT(..., M = M)  # M=5, fails!

# AFTER:
dsmatchATT(..., replace = TRUE)  # 1:1 matching with replacement
```

### Survey-Weighted Methods:
- **WDSM**: Still uses M=5 (designed for it)
- **PS Full**: Full matching (adapts automatically)

## Expected Results After Fix:

| Method | Before (M=5) | After (1:1) |
|--------|-------------|-------------|
| **DSM** | 0-48% valid | Should be ~100% valid |
| **PS** | 59-98% valid | Should be ~100% valid |
| **PG** | 100% valid | Stays 100% valid |
| **WDSM** | 100% valid | Stays 100% valid (M=5) |
| **PS Full** | 100% valid | Stays 100% valid |

## Why This Makes Sense:

1. **Unweighted methods** are meant to show baseline performance
2. **1:1 matching** is standard and feasible with 2:1 ratio
3. **WDSM with M=5** shows advantage of survey-weighted approach
4. **Comparison is now fair**: feasible matching for all methods

## Changes Made to Scripts:

All 4 scripts (CorCor, MisCor, CorMis, MisMis):
- Removed `M = M` from DSM/PS/PG calls
- Added `replace = TRUE` comment (already default)
- Kept `M = 5` only for WDSM
- Removed remaining timeouts

## Scientific Validity:

This comparison now properly shows:
- How unweighted 1:1 matching performs
- How survey-weighted full matching performs
- How survey-weighted M:1 matching (WDSM) performs
- All with the same complex survey data!
