# Differential Weight Normalization Experiment

## Hypothesis
WDSM may internally handle weight normalization differently than MatchIt's PS Full method, making external normalization unnecessary or potentially harmful for WDSM.

## Experimental Design

### Job ID: 57225723
- **Submitted**: August 10, 2025, 02:47
- **Replications**: 1000

### Weight Handling by Method

| Method | Weight Type | Normalization Applied |
|--------|-------------|----------------------|
| DSM (Unweighted) | None | N/A |
| PS (Unweighted) | None | N/A |
| PG (Unweighted) | None | N/A |
| **PS Full (Survey-Weighted)** | **Normalized** | **w × length(w)/sum(w)** |
| **WDSM V2 Standard GLM/LM** | **Raw** | **None (using 1/Prob directly)** |

## Implementation Details

### Code Changes
```r
# Create both raw and normalized weights
sample$weights_raw <- 1 / sample$Prob
sample$weights_normalized <- sample$weights_raw * length(sample$weights_raw) / sum(sample$weights_raw)

# PS Full uses normalized weights
sw = w  # w is normalized weights

# WDSM uses raw weights
weights = w_raw  # Use raw weights for WDSM
```

## Expected Outcomes

### If WDSM handles normalization internally:
- WDSM performance should remain good with raw weights
- PS Full should maintain good performance with normalized weights
- This would be the optimal configuration

### If WDSM needs external normalization:
- WDSM performance may degrade with raw weights
- Higher standard errors or biased estimates possible
- Would indicate normalization should be applied universally

## Comparison Structure

We will compare three configurations:
1. **No normalization** (Job 57092566): Neither method normalized
2. **Full normalization** (Job 57160958): Both methods normalized  
3. **Differential normalization** (Job 57225723): PS Full normalized, WDSM raw

## Key Metrics to Monitor
- **Relative Bias**: Should remain low (<1%) for survey-weighted methods
- **Coverage**: Should be close to nominal 95%
- **Standard Error Ratio**: Should be close to 1
- **Relative Efficiency**: Higher is better

## Scientific Rationale

Different implementations may handle survey weights differently:
- **MatchIt/marginaleffects**: Expects normalized weights for proper variance estimation
- **WDSM with bootstrap**: May compute normalization internally during bootstrap resampling
- **Influence functions**: May have built-in normalization in variance calculations

This experiment will help determine the optimal weight preprocessing for each method.
