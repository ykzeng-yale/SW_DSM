# CRITICAL ISSUES FOUND IN COMPARISON SCRIPTS

## 🚨 **MAJOR PROBLEM: DSM/PG/PS DON'T USE SURVEY WEIGHTS!**

### The Root Cause of Failures:

#### 1. **dsmatchATT DOES NOT ACCEPT SURVEY WEIGHTS**
```r
# Function signature (no weights parameter!):
dsmatchATT = function(Y, X, A, method = "dsm",
  model.ps = "other", ps = NULL, lp.ps = NULL,
  model.pg = "other", pg = NULL, lp.pg = NULL,
  caliper = NULL, replace = T, cov.balance = F,
  varest = F, boots = 100, mc = F, ncpus = 4, ...)
```

#### 2. **What's Happening in Our Scripts:**
```r
# We calculate survey weights from multi-stage sampling:
sample_data$survey_weight <- 1 / sample_data$Prob  # Ranges from 117 to 667!

# But DSM/PG/PS ignore them completely:
dsmatchATT(
  Y = Y,
  X = X_with_interaction,
  A = A,
  method = "dsm",  # or "pg" or "ps"
  # NO WEIGHTS PARAMETER!
  ...
)
```

#### 3. **Only PS_Full and WDSM Use Weights Correctly:**
```r
# PS_Full uses weights:
matchit(..., s.weights = ~ sw)

# WDSM uses weights:
sample_wdsm <- data.frame(..., w = w_original)
```

## Why This Causes Failures:

### DSM Failures (16-48% valid):
- Tries to match units ignoring their survey weights
- A unit with weight 667 is treated same as unit with weight 117
- Matching algorithm breaks down with this mismatch

### PS Failures (59-98% valid):
- Same issue - propensity scores estimated without weights
- Bootstrap variance estimation fails when data structure ignored

### Why PG Works (100% valid):
- Prognostic score is just regression prediction
- Less sensitive to weight misspecification
- But results are still WRONG (not survey-weighted)

## The Fundamental Problem:

**Multi-stage sampling with n=5000 and weights 117-667 CANNOT be analyzed by unweighted methods!**

The comparison is invalid because:
1. DSM, PG, PS treat all units equally (wrong!)
2. Some units represent 667 people, others only 117
3. Matching without weights is meaningless

## Solutions:

### Option 1: Use Survey-Weighted Methods Only
- PS_Full (via MatchIt with s.weights)
- WDSM (designed for survey weights)
- Drop DSM/PG/PS from comparison

### Option 2: Modify dsmatchATT to Accept Weights
- Major code modification required
- Would need weighted matching algorithm
- Weighted bootstrap for variance

### Option 3: Use Simple Random Sampling
- Go back to srswor with n=1000
- All units have equal weight
- DSM/PG/PS would work properly

## Current Results Are Misleading:

The "results" from DSM/PG/PS are essentially garbage because they're analyzing the wrong estimand:
- They estimate ATT for the unweighted sample
- We need PATT for the weighted population
- These are completely different quantities!

## Recommendation:

**The current comparison is fundamentally flawed.** Either:
1. Use only methods that handle survey weights (PS_Full, WDSM)
2. Revert to simple random sampling
3. Find/create weighted versions of DSM/PG/PS

The failures aren't bugs - they're the methods correctly refusing to produce invalid results!
