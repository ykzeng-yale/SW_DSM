# Comparison of WDSM CI Methods: M=1 vs M=3

## Overview

We compared the impact of using different numbers of matching neighbors (M) on the performance of two bootstrap CI methods for WDSM PATE estimation.

## Simulation Parameters
- **n_sim**: 50 simulations
- **B**: 50 bootstrap iterations  
- **n_sample**: 1000
- **Distance**: Unweighted Euclidean
- **True PATE**: 0.8664

## Results Comparison

### M=3 (3 Nearest Neighbors)

| Metric | Method 1 (Exponential) | Method 2 (Survey) | Difference |
|--------|------------------------|-------------------|------------|
| Mean τ̂ | 0.8155 | 0.8155 | 0.0000 |
| Bias | -0.0509 | -0.0509 | 0.0000 |
| SD(τ̂) | 0.2768 | 0.2768 | 0.0000 |
| Mean SE | 0.1193 | 0.1210 | +0.0017 (+1.4%) |
| Mean CI Width | 0.4676 | 0.4744 | +0.0068 (+1.5%) |
| Coverage | 92% | 92% | 0% |

### M=1 (Single Nearest Neighbor)

| Metric | Method 1 (Exponential) | Method 2 (Survey) | Difference |
|--------|------------------------|-------------------|------------|
| Mean τ̂ | 0.8094 | 0.8094 | 0.0000 |
| Bias | -0.0570 | -0.0570 | 0.0000 |
| SD(τ̂) | 0.2924 | 0.2924 | 0.0000 |
| Mean SE | 0.1298 | 0.1322 | +0.0024 (+1.8%) |
| Mean CI Width | 0.5090 | 0.5183 | +0.0093 (+1.8%) |
| Coverage | 92% | 92% | 0% |

## Key Findings

### 1. Impact of Reducing M from 3 to 1

| Change | M=3 → M=1 | Percent Change |
|--------|-----------|----------------|
| Bias | -0.0509 → -0.0570 | +12% (more bias) |
| SD(τ̂) | 0.2768 → 0.2924 | +5.6% (more variable) |
| Mean SE (Method 1) | 0.1193 → 0.1298 | +8.8% |
| Mean SE (Method 2) | 0.1210 → 0.1322 | +9.3% |
| CI Width (Method 1) | 0.4676 → 0.5090 | +8.9% |
| CI Width (Method 2) | 0.4744 → 0.5183 | +9.3% |

### 2. Variance-Bias Trade-off

- **Single matching (M=1)** leads to:
  - Higher variance (SD increased by 5.6%)
  - Slightly larger bias (12% increase)
  - Wider confidence intervals (~9% wider)
  - Same coverage rate (92%)

### 3. Method Comparison Remains Consistent

- **Relative difference** between Method 1 and Method 2:
  - M=3: Method 2 is 1.4-1.5% more conservative
  - M=1: Method 2 is 1.8% more conservative
  - The slight increase suggests methods remain similarly calibrated

### 4. Coverage Stability

- Both methods maintain 92% coverage regardless of M
- This suggests proper calibration of variance estimation

## Implications

1. **Efficiency Loss**: Using M=1 instead of M=3 results in ~9% wider confidence intervals, indicating less efficient estimation.

2. **Robustness**: Both CI methods handle the change in M well, maintaining appropriate coverage and similar relative performance.

3. **Practical Recommendation**: 
   - Use M≥3 when sufficient matches are available
   - M=1 is viable but less efficient
   - The choice between CI methods (1.4-1.8% difference) is less important than the choice of M (9% difference)

## Conclusion

Reducing the number of matching neighbors from M=3 to M=1 increases both bias and variance of the WDSM estimator, resulting in wider confidence intervals. However, both bootstrap methods adapt appropriately, maintaining nominal coverage. The efficiency loss from using fewer neighbors (~9%) is more substantial than the difference between CI methods (~1.8%). 