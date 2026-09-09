# ✅ Verification: Corrected Retrospective Sampling Implementation

## Summary
All comparison scripts have been **successfully updated** with the correct retrospective sampling from `SW_PSW-main`.

## Updated Files
✅ `PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R`
✅ `PATE Retrospective Pooroverlap M135 MisCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R`
✅ `PATE Retrospective Pooroverlap M135 CorMis GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R`
✅ `PATE Retrospective Pooroverlap M135 MisMis GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R`

## Correct Implementation Details

### 1. Retrospective Sampling Function ✅
```r
retrospective_sample <- function(population, n_sample) {
  N <- nrow(population)
  
  # Coefficients from SW_PSW-main/Sampling_DependOnTreatment_and_Estimation.R
  c0 <- log(n_sample/N / (1 - n_sample/N))
  c1 <- log(1.05)  
  c2 <- log(1.10)  
  c3 <- log(1.15)  
  c4 <- log(1.10) 
  c5 <- log(1.05) 
  c6 <- log(1.10) 
  delta_z_in_s <- log(0.9)
  
  # Probability-based sampling
  formula_S <- c0 + delta_z_in_s * population$A + 
               c1 * population$X1 + c2 * population$X2 +
               c3 * population$X3 + c4 * population$X4 + 
               c5 * population$X5 + c6 * population$X6
  
  prob_S <- exp(formula_S) / (1 + exp(formula_S))
  population$Prob <- prob_S
  
  # Sample based on probabilities
  population$S <- rbinom(N, 1, prob_S)
  sample_data <- population[population$S == 1, ]
  
  # Survey weights = inverse probability
  sample_data$survey_weight <- 1 / sample_data$Prob
  
  return(sample_data)
}
```

### 2. Weight Handling ✅

#### For WDSM:
```r
w_raw <- sample$survey_weight  # Use raw survey weights
ci_results <- compute_wdsm_method2_ci(
  weights = w_raw,  # ✅ Passes raw weights directly
  ...
)
```

#### For PS Full (MatchIt):
```r
w_normalized <- w_raw * length(w_raw) / sum(w_raw)  # ✅ Only normalized for MatchIt
```

### 3. Data Source ✅
```r
load("SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData")
```
- Generated with `delta_z = 2` for poor overlap
- Outcomes include X1:X2 interaction

### 4. Model Specification ✅
```r
use_interaction_ps <- (scenario == "CorCor" || scenario == "CorMis")
use_interaction_pg <- (scenario == "CorCor" || scenario == "MisCor")
```

## Key Differences from Previous Version

| Aspect | OLD (Incorrect) | NEW (Correct) |
|--------|-----------------|---------------|
| **Sampling Design** | Stratified (50/50 split) | Probability-based |
| **Sampling Formula** | Fixed n/2 each group | P(S=1) = expit(c0 + δz*A + c'X) |
| **Survey Weights** | N1/n1 or N0/n0 (2 values) | 1/Prob (unique per unit) |
| **Weight Distribution** | Bimodal | Continuous |
| **Matches SW_PSW-main** | ❌ No | ✅ Yes |

## Bootstrap Implications

The corrected sampling should improve:
1. **Coverage**: Bootstrap will better reflect the probability-based sampling variance
2. **SE Estimation**: More accurate with continuous weight distribution
3. **Bias**: Should remain low (WDSM already had good bias)

## Expected Results

With correct retrospective sampling:
- Coverage should improve from ~79% toward nominal 95%
- Bias should remain low (-3% to 3%)
- SE ratios should be closer to 1.0
- Results should be more consistent with good overlap patterns

## Ready for Submission

The scripts are now ready to be submitted with:
```bash
./submit_corrected_sampling_jobs.sh
```

This will submit jobs to the `tong` account with:
- 100 replicates
- M = 5
- 22 cores
- 8GB/CPU
- Correct retrospective sampling
- Correct model specifications
