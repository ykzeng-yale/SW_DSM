# Bootstrap Weights Summary for WDSM

## Weight Types

1. **Survey weights (w)**: Original sampling/survey weights
2. **Bootstrap weights (m_star)**: Multinomial resampling weights  
3. **Combined bootstrap weights (w_b)**: `w_b = w × m_star`
4. **Matching weights (K_M_w)**: Fixed weights from original matching indicating control unit reuse

## Correct Weight Usage in Bootstrap

### For Re-estimation:
- **PS model**: `weights = w_b` (survey × bootstrap) ✓
- **PG model**: `weights = w_b` (survey × bootstrap) ✓  
- **Polynomial sieve**: `weights = w_b` (survey × bootstrap) ✓

### Key Principle:
All models in bootstrap should use `w_b = survey × bootstrap` weights for re-estimation. We do NOT include matching weights K_M_w because:

1. **K_M_w is fixed** from the original matching - we don't re-match in bootstrap
2. **Bootstrap estimates population quantities** - we want μ₀ estimated on the bootstrap-resampled population
3. **Consistency** - all re-estimation uses the same bootstrap weights

### In the Augmentation Term:
The matching weights K_M_w are still used in the final augmentation term calculation:
```r
augment_term <- -w_b[j] * K_M_w[j] * (Y[j] - mu0_star[j]) / w_treated_sum
```
This is correct because K_M_w represents the fixed matching structure.

## Summary Table

| Component | Original Estimation | Bootstrap Re-estimation |
|-----------|-------------------|------------------------|
| PS model | `w` | `w_b = w × m_star` |
| PG model | `w` | `w_b = w × m_star` |
| Polynomial sieve | `K_M_w` | `w_b = w × m_star` |
| Augmentation term | `w × K_M_w` | `w_b × K_M_w` |

This implementation is consistent with the retrospective WDSM and theoretical bootstrap principles.