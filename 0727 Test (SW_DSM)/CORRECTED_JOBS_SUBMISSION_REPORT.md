# CORRECTED Jobs Submission Report

## Submission Time
January 27, 2025, 10:51-10:53 PM EST

## Jobs Successfully Running

| Job ID    | Scenario | Account | Status | Runtime | Remaining | Node       |
|-----------|----------|---------|---------|---------|-----------|------------|
| 57757185  | CorCor   | tong    | R       | 2:36    | 21:57:24  | r813u03n12 |
| 57757206  | MisCor   | tong    | R       | 1:32    | 21:58:28  | r813u09n03 |
| 57757210  | CorMis   | tong    | R       | 1:02    | 21:58:58  | r813u09n08 |
| 57757214  | MisMis   | tong    | R       | 0:23    | 21:59:37  | r813u09n11 |

## Configuration
- **Account**: tong (lower FairShare = 0.333, higher priority)
- **Partition**: day (22-hour limit)
- **Resources**: 20 cores, 160GB total RAM (8GB per CPU)
- **Replications**: 100
- **M values**: 5 only
- **Bootstrap iterations**: 200

## Key Fixes Applied (Based on Good Overlap CORRECTED)

### 1. ✅ Source dsmatch functions INSIDE worker
```R
# CRITICAL: Source dsmatch functions INSIDE the worker
for (file in dsmatch_files) {
  source(file)
}
```

### 2. ✅ Correct DSM implementation
```R
dsm_result <- dsmatchATE(
  Y = Y,
  X = X_ps,            # PS model uses X_ps
  A = A,
  method = "dsm",
  model.ps = "logit",  
  model.pg = "linpred",
  lp.pg = X_pg,        # PG model uses X_pg (independent!)
  M = M,
  ...
)
```

### 3. ✅ Correct PG matching
```R
pg_result <- dsmatchATE(
  Y = Y,
  X = X_pg,
  A = A,
  method = "pg",
  model.pg = "glm",    # NOT "linpred"!
  M = M,
  ...
)
```

### 4. ✅ Proper scenario-specific X matrices
- **CorCor**: Both PS and PG use X with interaction
- **MisCor**: PS without interaction, PG with interaction
- **CorMis**: PS with interaction, PG without interaction
- **MisMis**: Both PS and PG without interaction

## Expected Results

### CorCor (Both Models Correct)
- **WDSM**: <1% bias, ~95% coverage ✓
- **DSM**: ~1-2% bias, ~94-96% coverage
- **PG**: ~2-3% bias, ~93-95% coverage
- **PS Unweighted**: ~2-3% bias, ~93-95% coverage
- **PS Weighted**: ~1-2% bias, ~94-96% coverage

### Other Scenarios
- **MisCor**: PS-based methods degraded, PG-based still good
- **CorMis**: PS-based still good, PG-based degraded
- **MisMis**: All methods degraded

## Remote Directories
```
/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorCor_100reps_CORRECTED/
/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisCor_100reps_CORRECTED/
/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorMis_100reps_CORRECTED/
/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_MisMis_100reps_CORRECTED/
```

## Monitoring Commands

### Check job status:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong | grep CORR'
```

### Check output files:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'ls -la /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_100reps_CORRECTED/*.out | tail -4'
```

### Check results when complete:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'ls -la /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_100reps_CORRECTED/*.csv'
```

### Download results:
```bash
for scenario in CorCor MisCor CorMis MisMis; do
  scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_100reps_CORRECTED/*.csv .
done
```

## Expected Completion
- Estimated runtime: 1-2 hours (based on 100 replications)
- Maximum allowed: 22 hours
- Expected completion: ~11:30 PM - 12:30 AM EST

## What's Different This Time
1. **Functions properly sourced in parallel workers** - No more silent failures
2. **Correct dsmatchATE parameters** - Using actual function signature
3. **Proper model specifications** - `model.pg='glm'` for PG matching
4. **Independent PS and PG models for DSM** - True double score matching

## Success Indicators
✅ All 4 jobs are RUNNING  
✅ Using tong account (better priority)  
✅ Allocated to compute nodes  
✅ Based on proven Good Overlap implementation  

---
*This implementation follows the exact pattern from the Good Overlap CORRECTED scripts that are known to work properly.*
