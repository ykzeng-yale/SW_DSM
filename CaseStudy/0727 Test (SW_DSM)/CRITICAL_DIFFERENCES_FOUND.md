# 🚨 CRITICAL DIFFERENCES FOUND!

## Major Finding: Different Retrospective Sampling Methods!

### 1. POOR OVERLAP (Your version):
```r
retrospective_sample <- function(population, n_sample) {
  # STRATIFIED SAMPLING - Fixed 50/50 split
  n1 <- floor(n_sample / 2)
  n0 <- n_sample - n1
  
  # Sample indices
  idx1 <- sample(which(population$A == 1), n1, replace = FALSE)
  idx0 <- sample(which(population$A == 0), n0, replace = FALSE)
  
  # Survey weights based on strata
  sample_data$survey_weight <- ifelse(sample_data$A == 1, N1/n1, N0/n0)
}
```

### 2. GOOD OVERLAP (Reference version):
```r
retrospective_sample <- function(pop_data, n_sample = 1000) {
  # PROBABILITY-BASED SAMPLING with covariate-dependent selection
  c0 <- log(n_sample/N / (1 - n_sample/N))
  c1 <- log(1.05)  
  # ... more coefficients ...
  delta_z_in_s <- log(0.9)
  
  # Sampling probability depends on covariates and treatment
  formula_S <- c0 + delta_z_in_s * pop_data$A + c1 * pop_data$X1 + 
               c2 * pop_data$X2 + c3 * pop_data$X3 + ...
  
  prob_S <- expit(formula_S)
  pop_data$S <- rbinom(N, 1, prob_S)
  
  # Survey weights = 1/probability
  sample_data$survey_weight <- 1 / sample_data$Prob
}
```

## 🔴 This is a FUNDAMENTAL difference!

### Why This Matters:

1. **Sampling Design**: 
   - Poor overlap: Simple stratified sampling (50% treated, 50% control)
   - Good overlap: Complex probability sampling based on covariates

2. **Survey Weights**:
   - Poor overlap: Simple ratio weights (N1/n1, N0/n0)
   - Good overlap: Inverse probability weights (1/Prob)

3. **Implications**:
   - Different sampling designs require different variance estimators
   - Bootstrap behavior may differ
   - Weight distributions will be very different

## Other Key Differences:

### WDSM File Versions:
- Both use FIXED versions with `use_interaction_ps` and `use_interaction_pg` parameters ✅
- Both handle model specification correctly ✅

### Weight Normalization:
Both use the same approach for PS Full matching:
```r
w_normalized <- w_raw * length(w_raw) / sum(w_raw)
```

## 📊 Impact on Results:

The different retrospective sampling approaches could explain:
1. **Lower coverage** - Bootstrap may not correctly account for stratified sampling variance
2. **Different bias patterns** - Weights interact differently with estimation

## Recommendations:

### Option 1: Use Consistent Sampling
Change poor overlap to use the same probability-based sampling as good overlap

### Option 2: Adjust Bootstrap for Stratified Sampling
The multinomial bootstrap might need adjustment for stratified sampling design:
- Current: `w_star <- rmultinom(1, n, rep(1/n, n))[,1]`
- May need: Stratified bootstrap that respects the 50/50 design

### Option 3: Verify Which is Correct
Check with the original paper/specification which retrospective sampling design should be used:
- Stratified (equal allocation)
- Probability-based (covariate-dependent)

## Bottom Line:
The WDSM implementation itself is correct, but the **retrospective sampling design differs fundamentally** between good and poor overlap scenarios. This could be the source of the performance differences!
