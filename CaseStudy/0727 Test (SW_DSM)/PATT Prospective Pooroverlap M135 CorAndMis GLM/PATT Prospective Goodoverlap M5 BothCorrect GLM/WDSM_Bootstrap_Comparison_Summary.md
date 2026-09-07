# WDSM Bootstrap Implementation: dsmatch-style vs Manual

## Key Findings from dsmatch Analysis

### 1. dsmatch Bootstrap Architecture

**Uses boot package:**
```r
results <- boot::boot(data = data, statistic = estforboot_dsATT, R = boots,
                     model.ps = model.ps, ps = ps, lp.ps = lp.ps,
                     model.pg = model.pg, pg = pg, lp.pg = lp.pg,
                     parallel = "multicore", ncpus = ncpus)
```

**Key features:**
- Uses `boot::boot()` from the boot package
- Custom bootstrap functions (`estforboot_*`) for each method
- Supports parallel processing with `parallel = "multicore"`
- Recalculates scores in each bootstrap iteration
- Standard bootstrap resampling (not survey-weighted)

### 2. Score Recalculation in Bootstrap

From `estforboot_dsATE.R`:
```r
# Recalculates PS in each bootstrap iteration
if (model.ps == "logit"){
  glm.out <- glm(A ~ X, family = binomial(link = "logit"))
  ps <- cbind(1, X) %*% glm.out$coefficients
}
# Similar for prognostic scores
```

**Important:** dsmatch recalculates both PS and PG models on each bootstrap sample, which aligns with Yang & Zhang (2023) recommendations.

## Our WDSM Implementations

### Version 1: Manual Bootstrap (Current)
- **File:** `wdsm_patt_prospective_v1_simplified.R`
- **Method:** Manual loop with multinomial weights
- **Pros:** Full control over survey-weighted bootstrap
- **Cons:** No built-in parallel support, manual CI calculation

### Version 1 Robust: Manual Bootstrap with Ridge Fallback
- **File:** `wdsm_patt_prospective_v1_robust.R`
- **Method:** Same as V1 but with GLM → Ridge → Constant fallback
- **Pros:** Handles convergence issues
- **Cons:** Still manual bootstrap

### Version 2: boot Package Style (New)
- **File:** `wdsm_patt_prospective_v2_boot.R`
- **Method:** Uses `boot::boot()` like dsmatch
- **Key Adaptations:**
  ```r
  # Custom simulation for survey weights
  sim_fun <- function(data, mle) {
    w <- data[, "w"]
    p_weights <- w / sum(w)
    m_star <- rmultinom(1, n, p_weights)
    return(m_star)
  }
  
  boot(data = boot_data, statistic = boot_statistic,
       R = B, sim = "parametric", ran.gen = sim_fun)
  ```

## Key Differences: WDSM vs dsmatch

| Feature | dsmatch | WDSM |
|---------|---------|------|
| Bootstrap package | boot::boot() | Manual or boot::boot() |
| Resampling | Standard (indices) | Multinomial (survey weights) |
| PS estimation | binomial GLM | quasibinomial GLM |
| Fallback | None | Ridge regression (robust version) |
| Parallel | Built-in | Manual (V1) or built-in (V2) |
| CI calculation | boot.ci() | Percentile (V1) or boot.ci() (V2) |

## Survey-Weighted Bootstrap Specifics

### Standard Bootstrap (dsmatch):
```r
# Resample rows with replacement
data[sample(1:n, n, replace = TRUE), ]
```

### Survey-Weighted Bootstrap (WDSM):
```r
# Multinomial resampling with survey weights
p_weights <- w / sum(w)
m_star <- rmultinom(1, n, p_weights)
w_bootstrap <- w * m_star
```

## Recommendations

### For Production Use:

1. **Use V2 Boot for consistency with dsmatch:**
   - Leverages well-tested boot package
   - Built-in parallel support
   - Professional CI methods (BCa, etc.)
   - Easier to maintain

2. **Keep V1 Robust as fallback:**
   - Proven to work in our simulations
   - Ridge fallback addresses convergence
   - Manual control for debugging

### Implementation Details:

The V2 implementation maintains WDSM's theoretical requirements:
- Survey-weighted multinomial bootstrap
- Score recalculation in each iteration
- Fixed matching structure (following Yang & Zhang)
- Bias correction with weighted regression

### Code Example:
```r
# Using V2 with parallel bootstrap
result <- wdsm_patt_prospective_v2_boot(
  Y = Y, X = X, A = A, w = w,
  M = 5,           # Number of matches
  B = 500,         # Bootstrap iterations
  parallel = 20,   # Use 20 cores
  show_progress = TRUE
)
```

## Next Steps

1. **Testing:** Run `test_wdsm_versions_comparison.R` to compare all versions
2. **Validation:** Ensure V2 produces similar results to V1
3. **Performance:** Benchmark parallel efficiency
4. **Integration:** Update comprehensive comparison script

The boot package approach (V2) provides a more standardized, maintainable solution while preserving WDSM's survey-weighted bootstrap methodology.