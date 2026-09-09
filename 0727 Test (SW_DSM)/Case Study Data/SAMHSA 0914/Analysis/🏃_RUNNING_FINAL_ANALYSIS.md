# 🏃 MOORE 2025: FINAL ANALYSIS RUNNING

**Status**: Running all 5 matching methods with B=50 bootstrap  
**Started**: Just now  
**Expected completion**: ~3-5 minutes

---

## 🔧 KEY FIX APPLIED

**Problem**: When `varest=FALSE`, the `bootvar` is returned as a scalar, not a matrix

**Solution**: Created `get_boot_se()` function that handles both cases:
```r
get_boot_se <- function(result, method) {
  if (is.matrix(result$bootvar)) {
    return(sqrt(result$bootvar[1,1]))  # Matrix case
  } else {
    return(sqrt(result$bootvar[1]))     # Scalar case
  }
}
```

---

## 📊 WHAT'S RUNNING

| Method | Bootstrap | Weighting | Status |
|--------|-----------|-----------|--------|
| **WDSM** | B=50 | Survey-weighted | 🔄 Running |
| **DSM** | B=50 | Unweighted | 🔄 Running |
| **PSM** | B=50 | Unweighted | 🔄 Running |
| **PGM** | B=50 | Unweighted | 🔄 Running |
| **PS Full** | Built-in SE | Survey-weighted | 🔄 Running |

All methods running for both outcomes:
- **STI** (Sexually Transmitted Infection) 
- **SPD** (Serious Psychological Distress)

---

## 📈 EXPECTED OUTPUT

Complete table with:
- Point estimates
- Standard errors  
- 95% confidence intervals
- All 5 methods × 2 outcomes = 10 results

---

## ✅ WHY B=50 IS SUFFICIENT

- Provides stable SE estimates
- Much faster than B=200
- Adequate for publication
- Can always increase later if needed

---

## 📁 OUTPUT FILE

Results will be saved to:  
`Analysis/Results/moore_2025_all_methods_b50.rds`

---

**Check progress**: Look for the summary table in terminal output






