# Precise Results from 1000 Replicates

## Summary Table (All values to 3 decimal places)

| Method | Bias | Relative Bias (%) | Coverage | Relative Efficiency | SE Ratio | Empirical SD |
|--------|------|-------------------|----------|---------------------|----------|--------------|
| **DSM (Unweighted)** | 0.061 | 5.858 | 0.810 | 1.880 | 0.993 | 0.0572 |
| **PG (Unweighted)** | 0.061 | 5.894 | 0.796 | 1.818 | 0.962 | 0.0581 |
| **PS (Unweighted)** | 0.058 | 5.621 | 0.972 | 1.000 | 1.322 | 0.0784 |
| **PS Full (Survey-Weighted)** | -0.004 | -0.362 | 0.901 | 1.502 | 0.860 | 0.0639 |
| **WDSM V1 (Survey-Weighted)** | **-0.001** | **-0.139** | **0.967** | **1.667** | 1.096 | 0.0607 |

## Detailed WDSM V1 Statistics

- **Mean Estimate**: 1.033634 (True PATT: 1.035072)
- **Absolute Bias**: -0.001438
- **Relative Bias**: -0.139%
- **Empirical Standard Deviation**: 0.060685
- **Mean Reported Standard Error**: 0.066520
- **SE Ratio**: 1.096 (slight overestimation of variance)
- **Coverage**: 0.967 (96.700%)
- **Bootstrap Failures**: 0/1000
- **95% CI Width**: 0.260753

## Key Findings

1. **Best Overall Performance**: WDSM V1
   - Nearly unbiased (-0.139% relative bias)
   - Excellent coverage (96.7%, target: 95%)
   - Good efficiency (1.667 relative to PS)
   - No bootstrap failures

2. **Coverage Analysis**:
   - WDSM V1: 96.7% ✅ (nominal)
   - PS: 97.2% (conservative)
   - PS Full: 90.1% (under-coverage)
   - DSM: 81.0% (severe under-coverage)
   - PG: 79.6% (severe under-coverage)

3. **Bias Analysis**:
   - Survey-weighted methods (WDSM, PS Full) have minimal bias
   - Unweighted methods show ~6% relative bias
   - WDSM has the smallest absolute bias

4. **Efficiency Rankings** (Higher is better):
   - DSM (Unweighted): 1.880
   - PG (Unweighted): 1.818
   - WDSM V1: 1.667
   - PS Full: 1.502
   - PS (baseline): 1.000

5. **Standard Error Estimation**:
   - WDSM V1: SE ratio = 1.096 (slight overestimation, conservative)
   - PS Full: SE ratio = 0.860 (underestimation)
   - DSM/PG: SE ratio ≈ 0.96-0.99 (slight underestimation)
   - PS: SE ratio = 1.322 (overestimation, explains conservative coverage)

## Conclusion

WDSM V1 with all recent updates achieves the best balance of:
- Minimal bias (-0.139%)
- Nominal coverage (96.7%)
- Good efficiency (67% more efficient than PS)
- Stable estimation (0 bootstrap failures)
- Slightly conservative SE estimation (better than underestimation)