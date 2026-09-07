# FINAL Poor Overlap Jobs Submission Summary

## Submission Time
January 28, 2025, 12:34 AM EST

## Jobs Submitted to tong Account

| Job ID    | Scenario | Status | Configuration |
|-----------|----------|--------|---------------|
| 57759554  | CorCor   | Submitted | 20 cores, 160GB RAM, 23h limit |
| 57759557  | MisCor   | Submitted | 20 cores, 160GB RAM, 23h limit |
| 57759560  | CorMis   | Submitted | 20 cores, 160GB RAM, 23h limit |
| 57759576  | MisMis   | Submitted | 20 cores, 160GB RAM, 23h limit |

## Critical Fixes Applied ✅

### 1. REMOVED Invalid M Parameter
**Problem**: dsmatchATE doesn't have an M parameter
```R
# ❌ WRONG (caused "unused argument" errors):
dsmatchATE(..., M = M, ...)

# ✅ FIXED (matching Good Overlap CORRECTED):
dsmatchATE(...)  # No M parameter
```

### 2. REMOVED Individual Timeouts
**Problem**: Unnecessary timeout limits on individual replicates
```R
# ❌ WRONG (unnecessary):
result <- R.utils::withTimeout({
  run_single_replicate(...)
}, timeout = 300, onTimeout = "error")

# ✅ FIXED (job has 23-hour limit):
result <- run_single_replicate(...)  # No timeout
```

### 3. Kept All Correct Implementations
- ✅ Source dsmatch files INSIDE worker function
- ✅ DSM: X_ps for PS model, X_pg for PG model (independent)
- ✅ PG: model.pg='glm' (not 'linpred')
- ✅ PS: model.ps='logit'
- ✅ Scenario-specific interaction handling

## Expected Results

### CorCor (Both Models Correct)
- **DSM**: ~1-2% bias, ~94-96% coverage
- **PG**: ~2-3% bias, ~93-95% coverage
- **PS Unweighted**: ~2-3% bias, ~93-95% coverage
- **PS Weighted**: ~1-2% bias, ~94-96% coverage
- **WDSM**: <1% bias, ~95% coverage

### Other Scenarios
- **MisCor**: PS-based methods degraded, PG-based still good
- **CorMis**: PS-based still good, PG-based degraded
- **MisMis**: All methods degraded

## How This Matches Good Overlap CORRECTED

The FINAL implementation now **exactly matches** the Good Overlap CORRECTED structure:

| Aspect | Good Overlap CORRECTED | Poor Overlap FINAL |
|--------|------------------------|-------------------|
| M parameter in dsmatchATE | ✅ None | ✅ None |
| Individual timeouts | ✅ None | ✅ None |
| Source in worker | ✅ Yes | ✅ Yes |
| DSM parameters | ✅ X_ps, lp.pg | ✅ X_ps, lp.pg |
| PG model.pg | ✅ 'glm' | ✅ 'glm' |

## Remote Directories
```
/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorCor_100reps_FINAL/
/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisCor_100reps_FINAL/
/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorMis_100reps_FINAL/
/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisMis_100reps_FINAL/
```

## Monitoring Commands

### Check job status:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong | grep FINAL'
```

### Check if jobs are running:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong --format="%.18i %.9P %.8j %.8u %.10a %.2t %.10M %.6D"'
```

### Check output when running:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -20 /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorCor_100reps_FINAL/*.out'
```

### Download results when complete:
```bash
for scenario in CorCor MisCor CorMis MisMis; do
  scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_100reps_FINAL/*.csv .
done
```

## Timeline
- **Previous Attempts**: Failed due to M parameter issue
- **CORRECTED Attempt**: Failed due to M parameter (still had it)
- **FINAL Attempt**: Should work (matches Good Overlap exactly)

## Notes
1. dsmatchATE performs 1:1 matching by default (no k:1 matching support)
2. Bootstrap iterations: 200
3. Sample size: 5000 (retrospective sampling)
4. True PATE: 0.8664
5. Job time limit: 23 hours (day partition)

## Success Criteria
✅ All 5 methods produce results (no NAs)
✅ Coverage near 95% for correctly specified models
✅ Low bias (<5%) for correctly specified models
✅ Results degrade appropriately for misspecified models
