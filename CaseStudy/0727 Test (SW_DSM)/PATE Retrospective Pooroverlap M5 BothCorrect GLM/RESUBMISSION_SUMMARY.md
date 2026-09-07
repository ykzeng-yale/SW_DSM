# Resubmission Summary: Poor Overlap with Weight Normalization

## Why Resubmission Was Necessary

Survey weights MUST be normalized to sum to the sample size for proper variance estimation. The formula is:
```
w_normalized = w_raw × n / sum(w_raw)
```

Without this normalization:
- Survey weights can sum to very large values
- Variance estimates become unstable
- Coverage probabilities can be severely affected

## Job Details

### Previous Submission (WITHOUT normalization)
- **Job ID**: 57117031
- **Submitted**: 2025-08-05 10:56
- **Status**: Completed
- **Issue**: Survey weights not normalized

### New Submission (WITH normalization) ✅
- **Job ID**: 57161953
- **Submitted**: 2025-08-07 11:30
- **Status**: Pending (in queue)
- **Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_weighted_20250807/`

## Code Changes Made

In `compare_methods_pate_retrospective_mccleary.R`:
```r
# OLD (lines 94-95):
A <- sample$A
w <- sample$survey_weight

# NEW (lines 94-99):
A <- sample$A
w_raw <- sample$survey_weight

# CRITICAL: Normalize survey weights to sum to sample size
# This is essential for proper variance estimation
w <- w_raw * length(w_raw) / sum(w_raw)
```

## Expected Impact

1. **PS Full (Survey-Weighted)**: Should show improved coverage (previously 79.8%)
2. **WDSM**: May show more stable variance estimates
3. **All survey-weighted methods**: More reliable inference

## Methods Affected

- ✅ PS Full (Survey-Weighted) - MatchIt with survey weights
- ✅ WDSM (Multinomial Bootstrap) - All computations use normalized weights
- ❌ DSM, PG, PS Unweighted - Not affected (don't use survey weights)

## Commands to Monitor

Check status:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j 57161953'
```

Monitor output:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_weighted_20250807/pate_retro_*.out'
```

Download results when complete:
```bash
scp "yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_weighted_20250807/pate_retrospective_*.RData" .
scp "yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_weighted_20250807/pate_retrospective_*.pdf" .
scp "yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_weighted_20250807/pate_retrospective_*.csv" .
```

## Expected Runtime
1.5-2 hours based on previous runs