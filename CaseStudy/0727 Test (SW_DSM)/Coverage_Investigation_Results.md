# Coverage Investigation Results

## Key Finding: Coverage is NOT Hardcoded!

The 92% coverage rate (46/50 simulations) is genuine, not hardcoded. Here's what the investigation revealed:

## Why Coverage is Exactly 92% for Both M=1 and M=3

### 1. Same Simulations Fail
- **Both methods fail on the SAME 4 simulations**: #3, #11, #31, #37
- This happens because both methods produce identical point estimates (tau_hat)
- Only the standard errors differ slightly between methods

### 2. Extreme Outlier in Simulation #37
```
Simulation 37: tau_hat = -1.008, True PATE = 0.866
Z-score = -15.1 to -16.0 (!!!)
```
This is an extreme outlier where the estimate is off by nearly 2 units!

### 3. Z-Score Distribution Issues
- Mean z-score: -0.446 (should be ~0)
- SD of z-scores: 2.42 (should be ~1)
- This suggests:
  - Some bias in the estimator
  - Bootstrap SEs may underestimate true variability
  - Heavy tails in the sampling distribution

### 4. Coverage Calculation is Correct
The code correctly:
- Calculates CI using normal approximation: `tau_hat ± 1.96 * SE`
- Checks coverage: `(true_pate >= ci_lower) & (true_pate <= ci_upper)`
- Computes coverage rate as proportion of simulations covering truth

## Why M=1 and M=3 Have Same Coverage

1. **Point estimates are identical** between CI methods
2. **Same simulations are outliers** regardless of M
3. **SE differences are small** (~1-2%) between methods
4. **Outliers dominate coverage** - when estimates are off by 15+ SEs, small SE differences don't matter

## Implications

1. **92% coverage is reasonable** given:
   - Small sample (n_sim = 50)
   - 95% CI for coverage: [89%, 101%]
   - Some outliers are expected

2. **The extreme outlier (sim #37)** suggests:
   - Possible model misspecification for some samples
   - Matching may fail catastrophically in rare cases
   - Worth investigating sample characteristics

3. **Bootstrap may be underestimating uncertainty**:
   - SD of z-scores = 2.42 >> 1.0
   - Suggests need for bias correction or alternative variance estimation

## Recommendations

1. **Increase simulations** (n_sim ≥ 500) to get more precise coverage estimates
2. **Investigate outliers** - what makes simulation #37 so extreme?
3. **Consider robust methods** for handling occasional matching failures
4. **Test alternative variance estimators** (e.g., bias-corrected bootstrap) 