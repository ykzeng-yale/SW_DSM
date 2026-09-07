# Updated CI Methods Comparison Results
## Hyperparameters: n_sim=50, B=50, M=3

### Executive Summary

We compared two bootstrap methods for calculating 95% confidence intervals for WDSM PATE under retrospective sampling, using updated hyperparameters:
- **50 simulations** (increased from 10)
- **50 bootstrap iterations** (increased from 5)
- **M=3 neighbors** for matching (unchanged)

### Key Results

#### Coverage and Performance

| Metric | Method 1 (Exponential) | Method 2 (Survey) | Difference |
|--------|------------------------|-------------------|------------|
| **Coverage** | 92% (46/50) | 92% (46/50) | 0% |
| **Mean τ̂** | 0.8155 | 0.8155 | 0.0000 |
| **Bias** | -0.0509 | -0.0509 | 0.0000 |
| **SD(τ̂)** | 0.2768 | 0.2768 | 0.0000 |
| **Mean SE** | 0.1193 | 0.1210 | +0.0017 (+1.4%) |
| **Mean CI Width** | 0.4676 | 0.4744 | +0.0068 (+1.5%) |

#### Extreme Values

| Method | Min SE | Max SE | Min CI Width | Max CI Width |
|--------|--------|--------|--------------|--------------|
| Method 1 | 0.0864 | 0.1440 | 0.3386 | 0.5644 |
| Method 2 | 0.0890 | 0.1538 | 0.3490 | 0.6030 |

### Key Findings

1. **Coverage Rate**: Both methods achieved 92% coverage, which is closer to the nominal 95% level than perfect coverage, indicating better calibration with more simulations.

2. **Minimal Differences**: The differences between methods remain very small:
   - Standard error difference: 1.4%
   - CI width difference: 1.5%
   - Method 2 remains slightly more conservative

3. **Identical Point Estimates**: Both methods produce exactly the same point estimates (confirmed by max difference < 1e-10).

4. **Consistency**: Results are consistent with the initial small-scale test, confirming the robustness of both methods.

### Comparison with Previous Results (n_sim=10, B=5)

| Metric | Previous | Current | Change |
|--------|----------|---------|--------|
| Coverage (both methods) | 100% | 92% | -8% |
| SE difference | 3.8% | 1.4% | -2.4% |
| CI width difference | 3.7% | 1.5% | -2.2% |

The increased sample size reveals:
- More realistic coverage rates
- Even smaller differences between methods
- Greater confidence in the equivalence of both approaches

### Statistical Significance

With 50 simulations:
- Standard error for coverage estimate: √(0.92 × 0.08 / 50) ≈ 0.038
- 95% CI for coverage: 92% ± 7.5% = [84.5%, 99.5%]

Both methods' coverage rates are not significantly different from the nominal 95% level.

### Recommendations

1. **Both methods remain valid** for WDSM variance estimation under retrospective sampling.

2. **Practical equivalence**: With differences of only ~1.5%, the choice between methods can be based on:
   - Computational convenience
   - Theoretical preference
   - Integration with existing code

3. **Coverage calibration**: The 92% coverage suggests both methods are slightly anti-conservative, but within acceptable bounds.

4. **Next steps**:
   - For publication-quality results, increase to B ≥ 1000
   - Test under different scenarios (poor overlap, misspecification)
   - Consider bias-corrected methods if exact 95% coverage is critical

### Conclusion

The updated simulation with more realistic parameters confirms that both CI methods perform nearly identically. The small differences observed (Method 2 being ~1.5% more conservative) are negligible for practical applications. Both methods provide reliable inference for WDSM PATE under retrospective sampling with survey weights. 