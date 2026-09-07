# Mixed Normalization Experiment

## Hypothesis
WDSM's multinomial bootstrap may handle raw survey weights correctly internally, while PS Full (MatchIt) requires normalized weights for proper variance estimation.

## Three Versions Submitted

### Version 1: No Normalization (Original)
- **Job ID**: 57117031 (Completed)
- **Both PS Full and WDSM**: Raw weights (1/sampling_prob)
- **Result**: PS Full coverage = 79.8% ❌

### Version 2: Full Normalization  
- **Job ID**: 57161953 (Completed)
- **Both PS Full and WDSM**: Normalized weights (w × n/sum(w))
- **Result**: PS Full coverage = 79.8% (no improvement) ❌

### Version 3: Mixed Normalization ✨ NEW
- **Job ID**: 57225805 (Just submitted)
- **PS Full**: Normalized weights (w × n/sum(w))
- **WDSM**: Raw weights (1/sampling_prob)
- **Submitted**: 2025-08-09
- **Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_mixed_20250809/`

## Code Changes in Mixed Version

```r
# Extract variables
Y <- sample$Y
X <- as.matrix(sample[, c("X1", "X2", "X3", "X4", "X5", "X6")])
A <- sample$A
w_raw <- sample$survey_weight  # RAW weights (1/sampling_prob)

# MIXED NORMALIZATION APPROACH:
# Create normalized weights for PS Full (Survey-Weighted)
# But keep raw weights for WDSM
w <- w_raw * length(w_raw) / sum(w_raw)  # Normalized for PS Full only

# ...

# PS Full uses normalized weights (w)
m_ps_sw <- matchit(
  A ~ X1 + X2 + X3 + X4 + X5 + X6 + X1:X2,
  data = match_data_sw,
  method = "full",
  distance = "glm",
  link = "logit",
  s.weights = ~ sw,  # This uses normalized w
  estimand = "ATE"
)

# ...

# WDSM uses raw weights (w_raw)
ci_results <- compute_wdsm_method2_ci(
  Y = Y, A = A, X = X, weights = w_raw,  # Using RAW weights for WDSM
  M = M,
  n_bootstrap = B,
  alpha = alpha,
  use_bias_correction = TRUE,
  return_samples = FALSE
)
```

## Expected Outcomes

### If hypothesis is correct:
- PS Full coverage should remain ~80% (still problematic)
- WDSM should maintain good performance (~93% coverage)
- This would confirm WDSM handles raw weights correctly

### If hypothesis is incorrect:
- WDSM performance might degrade with raw weights
- This would suggest normalization is important for WDSM too

## Monitor Progress

Check job status:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j 57225805'
```

Check output:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_mixed_20250809/pate_retro_*.out'
```

Download results when complete:
```bash
scp "yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_mixed_20250809/pate_retrospective_*.{RData,pdf,csv}" .
scp "yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_mixed_20250809/pate_retro_*.out" .
```

## Runtime
Expected: 1.5-2 hours based on previous runs
