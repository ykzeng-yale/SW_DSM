# CRITICAL FIX: Multi-stage Sampling Correction

## The Problem Found

### WRONG Implementation (Before):
```r
# Simple random sampling
s <- srswor(n = 1000, N = nrow(data_full))
sample_data <- data_full[s == 1, ]
sample_data$survey_weight <- 1000  # Constant weight
```

**Issues:**
- Sample size: Only 1000
- Weights: All identical (no variation)
- Design: Simple random (no clustering)
- This fundamentally changed the statistical properties!

### CORRECT Implementation (Fixed):
```r
# Multi-stage sampling (from SW_PSW-main/Sampling_MultiStage_and_Estimation.R)
s <- mstage(data_full, 
           stage = list("stratified", "cluster", ""), 
           varnames = list("Strata", "Cluster", "ones"), 
           size = list(size1, size2, size3), 
           method = list("", "srswor", "srswor"))

sample_data <- getdata(data_full, s)[[3]]
sample_data$survey_weight <- 1 / sample_data$Prob  # Complex weights
```

**Correct Design:**
- Sample size: 5000 (5x larger!)
- Weights: Variable (117-667 range)
- Design: Stratified cluster sampling
- 10 strata, 5 clusters per stratum

## Why This Matters

1. **Sample Size Impact:**
   - 5000 vs 1000 = Much more stable estimates
   - Better representation of population
   - More treated units (~1500 vs ~300)

2. **Weight Variation:**
   - Complex weights reflect sampling design
   - Different units have different importance
   - Affects standard error calculations

3. **Clustering Effects:**
   - Within-cluster correlation
   - Design effects on variance
   - Different statistical properties

## Expected Changes in Results

### Before (Simple Random):
- PS had inflated SE due to small sample + poor overlap
- 100% coverage even under misspecification
- Results seemed "fishy"

### After (Multi-stage):
- Larger sample should stabilize estimates
- Complex weights may change SE patterns
- Coverage should be more realistic
- Better differentiation between scenarios

## Jobs Submitted

- **Job 57812410**: CorCor (Both correct)
- **Job 57812446**: MisCor (PS misspecified)
- **Job 57812447**: CorMis (PGS misspecified)
- **Job 57812448**: MisMis (Both misspecified)

All using corrected multi-stage sampling with n=5000.

## Lesson Learned

**ALWAYS check the original sampling design!** Using the wrong sampling method completely invalidates the simulation, even if everything else is correct.
