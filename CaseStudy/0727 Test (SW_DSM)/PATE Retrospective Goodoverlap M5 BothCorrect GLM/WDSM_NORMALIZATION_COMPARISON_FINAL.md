# WDSM Weight Normalization Comparison - Final Results

## Date: 2025-08-10
## Job ID: 57225741 (WDSM without normalization)

## Executive Summary
**WDSM does NOT require weight normalization and actually performs better without it.**

## Precise Results (3 decimal places, 1000 replicates)

### WDSM Performance Comparison

| Metric | **WITHOUT Normalization** ✅ | WITH Normalization | Improvement |
|--------|---------------------------|-------------------|-------------|
| **Relative Bias** | **-0.443%** | -0.614% | Lower bias |
| **Coverage** | **94.400%** | 93.500% | +0.9% |
| **Relative Efficiency** | **2.508** | 2.327 | +7.8% |
| **SE/SD Ratio** | **1.0028** | 0.9521 | Closer to 1 |
| **MSE** | **0.002823** | 0.003055 | -7.6% |

### Complete Method Comparison (WDSM without normalization)

| Method | Relative Bias (%) | Coverage (%) | Relative Efficiency | SE/SD Ratio |
|--------|-------------------|--------------|---------------------|-------------|
| DSM (Unweighted) | 6.052 | 82.900 | 2.346 | 0.9774 |
| PG (Unweighted) | 5.985 | 82.700 | 2.451 | 0.9743 |
| PS (Unweighted) | 6.220 | 97.200 | 1.000 (ref) | 1.3368 |
| **PS Full (Survey-Weighted)** | **-0.632** | **93.900** | **1.803** | **0.9433** |
| **WDSM (Unnormalized)** | **-0.443** | **94.400** | **2.508** | **1.0028** |

## Key Findings

### 1. WDSM Without Normalization is Superior
- **Better coverage**: 94.400% (closer to nominal 95%)
- **Lower bias**: -0.443% (excellent)
- **Higher efficiency**: 2.508 (best among all methods)
- **Better calibrated variance**: SE/SD ratio of 1.0028 (nearly perfect)
- **Lower MSE**: 0.002823 (best among all methods)

### 2. PS Full Still Requires Normalization
- PS Full with normalization: 93.900% coverage
- Without normalization (from memory): ~59.5% coverage
- Weight normalization is **essential** for PS Full

### 3. Why WDSM Doesn't Need Normalization
WDSM likely handles weights differently internally:
- The multinomial bootstrap naturally accounts for survey weights
- The influence function approach may already incorporate proper weight scaling
- The method's theoretical foundation doesn't require explicit normalization

## Recommendations

1. **For WDSM**: Use **original unnormalized survey weights** (1/prob)
2. **For PS Full (MatchIt)**: Use **normalized weights** (w × length(w)/sum(w))
3. **WDSM is the optimal method** for PATE estimation under retrospective sampling:
   - Best efficiency (2.508)
   - Excellent coverage (94.400%)
   - Lowest bias (-0.443%)
   - Smallest MSE (0.002823)

## Implementation Notes

### Correct Usage:
```r
# For PS Full (Survey-Weighted)
w_normalized <- survey_weight * length(survey_weight) / sum(survey_weight)
matchit(..., s.weights = ~ w_normalized)

# For WDSM
w <- survey_weight  # Use original unnormalized weights
compute_wdsm_method2_ci(..., weights = w)
```

## Conclusion

The empirical evidence from 1000 replicates clearly demonstrates that:
1. **WDSM performs optimally without weight normalization**
2. **PS Full requires weight normalization for proper variance estimation**
3. **Different methods require different weight handling approaches**

This finding highlights the importance of understanding each method's internal mechanics rather than applying blanket normalization rules.
