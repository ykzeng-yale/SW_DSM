# Version Notes: PATT Prospective Good Overlap M5 Both Correct GLM

## What Makes This Version "Both Correct"

### 1. **Correct GLM Family for Survey Weights**
- ✅ **WDSM**: Uses `quasibinomial()` for PS estimation
- ✅ **MatchIt**: Automatically uses `quasibinomial()` with survey weights
- ✅ **Consistency**: All survey-weighted methods now use the same family

### 2. **Correct Interaction Term Handling**
- ✅ All methods include X1:X2 interaction term
- ✅ WDSM automatically creates it internally
- ✅ Other methods explicitly include it in model matrix

## Key Code Changes

### WDSM PS Estimation (Line 78 of wdsm_patt_prospective_v1_simplified.R):
```r
# OLD VERSION:
ps_model <- glm(ps_formula, data = ps_data, family = binomial(link = "logit"), 
                weights = w)

# NEW VERSION (CORRECT):
ps_model <- glm(ps_formula, data = ps_data, family = quasibinomial(link = "logit"), 
                weights = w)
```

### Why This Matters:
1. **Overdispersion**: Survey weights induce overdispersion in binary outcomes
2. **Standard Errors**: Quasibinomial adjusts SEs for this overdispersion
3. **Consistency**: Aligns with standard practice in survey analysis

## Comparison with Previous Versions

| Aspect | Previous Version | This Version |
|--------|-----------------|--------------|
| WDSM PS Family | binomial | quasibinomial |
| MatchIt PS Family | quasibinomial (auto) | quasibinomial (auto) |
| Interaction Terms | ✓ | ✓ |
| Bootstrap | ✓ | ✓ |
| HPC Optimization | ✓ | ✓ |

## Expected Impact

1. **More Conservative SEs**: Quasibinomial typically produces slightly larger SEs
2. **Better Coverage**: Should improve coverage properties
3. **Theoretical Soundness**: Aligns with survey statistics best practices

## Submission Timeline

1. **Job 57076705** (11:34) - Original version with binomial
2. **Job 57080035** (13:16) - This version with quasibinomial ✓

## Note on Bootstrap

While the GLM family affects the PS model fitting, the final inference relies on bootstrap variance estimation, which should provide valid results regardless. However, using the correct family is theoretically more sound and may improve finite sample performance.

## Critical Update: Polynomial Sieve Bootstrap (August 4, 2025)

### 3. **Polynomial Sieve Method** ✅
- **Implemented**: Polynomial sieve for bias correction `Y ~ mu0 + mu0^2 + ps + ps^2 + ps*mu0`
- **Previous**: Simple linear model `Y ~ s1 + s2 + s1:s2`

### 4. **Re-fitting Models in Bootstrap** ✅ (CRITICAL FIX)
- **Fixed**: Now re-fits polynomial sieve model in each bootstrap iteration
- **Previous**: Used fixed model from initial estimation (incorrect)
- **Impact**: Eliminated bootstrap failures (0 failures vs 370/1000 previously)

This aligns with dsmatch-master's approach and ensures proper variance estimation.

### 6. **Bootstrap Weights Correction** ✅ (Fixed August 4, 2025)
- **Fixed**: Polynomial sieve in bootstrap now uses survey × bootstrap weights only
- **Previous**: Used (survey × bootstrap) × matching weights 
- **Key insight**: K_M_w (matching weights) are fixed from original matching and should not be included in bootstrap re-estimation
- **Correct weights**:
  - PS re-estimation: `w_b = survey × bootstrap` ✓
  - PG re-estimation: `w_b = survey × bootstrap` ✓
  - Polynomial sieve: `w_b = survey × bootstrap` ✓ (NOT `w_b × K_M_w`)

This ensures we estimate μ₀ on the bootstrap-resampled population, consistent with the retrospective implementation.

### 7. **Comprehensive Comparison Script Update** ✅ (Fixed August 4, 2025)
- **Fixed**: `comprehensive_patt_comparison_mccleary.R` now uses `wdsm_patt_prospective_v1_simplified`
- **Previous**: Used `wdsm_patt_prospective_v1_robust` which lacked polynomial sieve and weighted standardization
- **Impact**: All WDSM results will now use the fully updated implementation

### 5. **Weighted Standardization** ✅ (Added August 4, 2025)
- **Implemented**: Weighted standardization for double scores
- **Previous**: Unweighted standardization using `colMeans()` and `sd()`
- **Impact**: More theoretically correct for survey-weighted data, ensures proper handling of weights in matching

The weighted standardization computes:
- Weighted mean: `colSums(weights * S) / sum(weights)`
- Weighted SD: `sqrt(colSums(weights * (S - mean)^2) / sum(weights))`

This aligns with the retrospective WDSM implementation and survey statistics best practices.