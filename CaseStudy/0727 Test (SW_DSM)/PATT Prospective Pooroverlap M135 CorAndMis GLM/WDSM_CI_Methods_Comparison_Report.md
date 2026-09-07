# WDSM Confidence Interval Methods Comparison Report

## Summary

This report compares two versions of the Weighted Double Score Matching (WDSM) confidence interval calculation methods for PATT (Population Average Treatment Effect on the Treated) under prospective sampling.

### Test Parameters
- Number of matches (M): 3
- Bootstrap iterations (B): 5 (small for testing)
- Number of resampling iterations: 10
- Sample size: ~5,000 per iteration
- True PATT from population: 1.0351

## Key Findings

### 1. Point Estimates
Both versions produce **identical point estimates** for each iteration, confirming that the bias-corrected estimator is implemented consistently in both versions.

- Mean tau_hat (both versions): 1.0646
- Bias (both versions): 0.0295
- RMSE (both versions): 0.0558

### 2. Standard Error Estimation
The two versions differ significantly in their standard error estimates:

- **Version 1 Mean SE**: 0.0534
- **Version 2 Mean SE**: 0.0745

Version 2 produces standard errors that are approximately 40% larger than Version 1.

### 3. Coverage Performance
- **Version 1**: 100.0% coverage
- **Version 2**: 90.0% coverage

Version 1 appears to be conservative (over-covering), while Version 2 is slightly below the nominal 95% level.

## Method Differences

### Version 1 Key Features:
1. Uses multinomial bootstrap weights: `ω*ᵢ = m*ᵢ/n` where `m* ~ Multinomial(n, p₁,...,pₙ)`
2. Stores and fixes K_M^w(j) matching frequencies
3. Uses linear approximation without re-matching
4. Evaluates μ₀ at new bootstrap score values but using original model

### Version 2 Key Features:
1. Uses standard bootstrap (drawing with replacement): `ω*ᵢ = m*ᵢ` where m*ᵢ is count
2. Stores and fixes K_{M,ATT}^w(i) weighted reuse factors
3. Re-estimates μ₀ function in each bootstrap iteration
4. Uses theoretically-derived linearized formula

## Individual Iteration Results

| Iteration | Sample Size | Treated | Control | V1 tau_hat | V1 SE | V1 CI | V2 tau_hat | V2 SE | V2 CI |
|-----------|-------------|---------|---------|------------|-------|-------|------------|-------|-------|
| 1 | 5000 | 1574 | 3426 | 1.0737 | 0.0362 | [1.0027, 1.1447] | 1.0737 | 0.0850 | [0.9071, 1.2403] |
| 2 | 5000 | 1551 | 3449 | 1.0220 | 0.0422 | [0.9394, 1.1047] | 1.0220 | 0.1128 | [0.8010, 1.2431] |
| 3 | 5000 | 1587 | 3413 | 1.1097 | 0.0593 | [0.9935, 1.2260] | 1.1097 | 0.0234 | [1.0639, 1.1556] |
| 4 | 5000 | 1586 | 3414 | 1.0875 | 0.0635 | [0.9631, 1.2119] | 1.0875 | 0.1216 | [0.8491, 1.3259] |
| 5 | 5000 | 1552 | 3448 | 0.9838 | 0.0584 | [0.8693, 1.0983] | 0.9838 | 0.0582 | [0.8697, 1.0979] |
| 6 | 5000 | 1613 | 3387 | 1.1003 | 0.0489 | [1.0046, 1.1961] | 1.1003 | 0.0662 | [0.9706, 1.2301] |
| 7 | 5000 | 1625 | 3375 | 1.0238 | 0.0549 | [0.9162, 1.1315] | 1.0238 | 0.1141 | [0.8002, 1.2475] |
| 8 | 5000 | 1605 | 3395 | 1.1340 | 0.0739 | [0.9892, 1.2788] | 1.1340 | 0.0676 | [1.0015, 1.2665] |
| 9 | 5000 | 1599 | 3401 | 1.0971 | 0.0489 | [1.0014, 1.1929] | 1.0971 | 0.0478 | [1.0034, 1.1908] |
| 10 | 5000 | 1594 | 3406 | 1.0137 | 0.0482 | [0.9192, 1.1081] | 1.0137 | 0.0482 | [0.9191, 1.1082] |

## Observations

1. **Variability in SE estimates**: Version 2 shows much higher variability in SE estimates across iterations (ranging from 0.0234 to 0.1216) compared to Version 1 (0.0362 to 0.0739).

2. **Similar performance in some cases**: In iterations 5, 9, and 10, both versions produced very similar SE estimates.

3. **Bootstrap stability**: With only B=5 bootstrap iterations, the estimates may not be fully stable. A larger B (e.g., 500) would provide more reliable variance estimates.

## Recommendations

1. **For immediate use**: Version 1 appears more stable but may be conservative. Its consistent over-coverage suggests it provides valid but possibly wide intervals.

2. **Further investigation needed**:
   - Run simulations with larger B (500-1000) to assess stability
   - Test on different sample sizes and population configurations
   - Evaluate performance under model misspecification

3. **Theoretical considerations**: Version 2's re-estimation of μ₀ in each bootstrap iteration may better capture model uncertainty, but the implementation may need refinement to achieve nominal coverage.

## Conclusion

Both methods produce unbiased point estimates with reasonable performance. Version 1 provides more conservative inference with stable standard errors, while Version 2's approach may need adjustment to achieve nominal coverage. The choice between methods depends on whether conservative (Version 1) or potentially more efficient (Version 2) inference is preferred. 