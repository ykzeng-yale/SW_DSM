# Diagnosis of Extreme Point Estimates in WDSM

## Key Finding: Propensity Score Model Failure

### Problematic Samples (seeds 2027, 2036, 2038, 2043)
All showed catastrophic propensity score model failure:
- **All propensity scores = 2.22e-16** (essentially 0)
- This includes treated units, which should have higher propensity
- GLM convergence warnings present
- Point estimates: -2.28, -1.99, -1.25, 2.19 (true = 0.866)

### Normal Samples (seeds 2025, 2026)
Showed proper propensity score estimation:
- Reasonable distribution (mean ~0.42 for seed 2025)
- Good overlap between treatment groups
- Point estimates: 0.853, 0.883 (close to true = 0.866)

## Other Components Analysis

### Survey Weights
- **Not the primary issue**
- Mean: ~205 (reasonable)
- Max: ~450-520 (high but not extreme)
- Effective sample size: ~94-95% of actual

### Prognostic Scores
- Appear reasonable in all samples
- Mean Y(0): ~-0.08 to -0.12
- Mean Y(1): ~0.80 to 0.90

### Outcomes
- Similar distributions across all samples
- Mean Y: ~0.25-0.31
- No extreme outliers causing the problem

## Root Cause

The GLM for propensity score estimation is experiencing complete separation or quasi-separation in certain samples, leading to:
1. All predicted probabilities collapsing to 0
2. Degenerate double scores (everyone has same propensity component)
3. Matching becomes meaningless
4. Extreme and unstable estimates

## Why This Happens

In retrospective sampling with treatment-dependent selection:
- Some samples may have covariate configurations that perfectly or nearly perfectly separate treatment groups
- The GLM tries to fit infinite coefficients, leading to numerical issues
- The predictions collapse to boundary values (0 or 1)

## Implications

1. The bootstrap variance estimation assumes the point estimate is reasonable
2. When the point estimate is corrupted by model failure, the bootstrap can't fix it
3. This explains why coverage is poor - the estimator itself is unstable

## Recommended Solutions

1. **Regularization**: Add penalty to propensity score model (e.g., ridge/lasso)
2. **Trimming**: Exclude units with extreme propensity scores
3. **Model diagnostics**: Check for separation before proceeding
4. **Alternative models**: Use more stable propensity score estimation methods
5. **Overlap enforcement**: Ensure common support before matching 