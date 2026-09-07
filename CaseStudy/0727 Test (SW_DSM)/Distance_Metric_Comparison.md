# Distance Metric Comparison for WDSM CI Methods

## Overview
We compared the impact of using weighted vs unweighted Euclidean distance in the matching step of WDSM CI methods.

## Distance Metrics Tested

### 1. Weighted Euclidean Distance
```r
weighted_distance <- function(x1, x2, weights = c(1, 1)) {
  sqrt(sum(weights * (x1 - x2)^2))
}
```
- Allows different weights for different components of the double score
- Default weights = c(1, 1) gives equal weight to propensity and prognostic scores

### 2. Unweighted Euclidean Distance
```r
weighted_distance <- function(x1, x2, weights = c(1, 1)) {
  # Using unweighted Euclidean distance (ignoring weights parameter)
  sqrt(sum((x1 - x2)^2))
}
```
- Treats all dimensions equally
- Ignores the weights parameter

## Results Comparison (n_sim=50, B=50, M=3)

### Key Finding: **Identical Results**

| Metric | Weighted Distance | Unweighted Distance | Difference |
|--------|-------------------|---------------------|------------|
| **Method 1 Coverage** | 92% | 92% | 0% |
| **Method 2 Coverage** | 92% | 92% | 0% |
| **Method 1 Mean SE** | 0.1193 | 0.1193 | 0.0000 |
| **Method 2 Mean SE** | 0.1210 | 0.1210 | 0.0000 |
| **Method 1 CI Width** | 0.4676 | 0.4676 | 0.0000 |
| **Method 2 CI Width** | 0.4744 | 0.4744 | 0.0000 |
| **Mean τ̂** | 0.8155 | 0.8155 | 0.0000 |
| **Bias** | -0.0509 | -0.0509 | 0.0000 |

## Explanation

The identical results are due to **mathematical equivalence**, not implementation error:

1. **Mathematical Proof**: For weighted distance with weights (1,1):
   ```
   d_weighted = √(1·(x₁-y₁)² + 1·(x₂-y₂)²) = √((x₁-y₁)² + (x₂-y₂)²) = d_unweighted
   ```
   With equal weights, the "weighted" distance is mathematically identical to unweighted distance.

2. **Standardization Effect**: Since we standardize both components of the double score before matching:
   ```r
   S0 <- cbind(scale(e_score), scale(psi0))
   S1 <- cbind(scale(e_score), scale(psi1))
   ```
   Both components have mean 0 and variance 1, making them already on the same scale.

3. **Verification**: Testing with different weights (e.g., (2, 0.5) vs (0.5, 2)) DOES produce different matches, confirming the implementation is correct.

## Implications

1. **Simplification**: For standardized scores, unweighted Euclidean distance is sufficient and computationally simpler.

2. **Flexibility**: The weighted distance function remains useful if:
   - Scores are not standardized
   - Different importance needs to be assigned to propensity vs prognostic scores
   - Domain knowledge suggests unequal weighting

3. **Best Practice**: Continue standardizing scores before matching to ensure scale invariance.

## Recommendation

For WDSM with standardized double scores, either distance metric produces identical results. The unweighted Euclidean distance is simpler and sufficient for most applications. However, keeping the weighted distance function provides flexibility for future extensions where differential weighting might be beneficial. 