# 1000-Replication Production Run Status

## ✅ Successfully Submitted to li_fan Account

### Job Details

| Scenario | Job ID | Status | Start Time | Time Limit | Account | CPUs |
|----------|--------|--------|------------|------------|---------|------|
| **CorCor** | 57897693 | 🟡 PENDING | 18:23 | 23:00:00 | li_fan | 12 |
| **MisCor** | 57897704 | 🟡 PENDING | 18:24 | 23:00:00 | li_fan | 12 |
| **CorMis** | 57897706 | 🟡 PENDING | 18:24 | 23:00:00 | li_fan | 12 |
| **MisMis** | 57897719 | 🟡 PENDING | 18:25 | 23:00:00 | li_fan | 12 |

**Queue Status**: QOSMaxCpuPerUserLimit (waiting for resources)

## Configuration (Identical to 100-rep except replications)

### Simulation Parameters
- **Replications**: 1000 (10x more than 100-rep run)
- **Sample size**: n = 5000
- **Bootstrap**: B = 200
- **Matching ratio**: M = 5
- **True PATE**: 0.8664 (poor overlap)
- **Account**: li_fan (changed from tong)

### All Fixes Applied ✅
1. **Sample size**: n=5000 (corrected from 1000)
2. **Function names**: compute_wdsm_method2_ci_FIXED
3. **dsmatchATE fields**: est.ds, est.pg, est.ps  
4. **SE calculation**: sqrt(bootvar[1,1])
5. **CI calculation**: qnorm-based
6. **All 5 methods enabled**: DSM, PG, PS, PS Full, WDSM

### Remote Directory
```
/gpfs/gibbs/project/li_fan/yz2324/pooroverlap_1000rep_20250823_182203
```

## Key Changes from Previous Runs

### 1. Account Change
- **From**: tong account
- **To**: li_fan account

### 2. Replication Scaling
- 20 reps → 100 reps → **1000 reps**
- Only changed `n_reps <- 1000` for consistency

### 3. Time Limit
- **Set to 23 hours** (full day partition limit)
- Expected runtime: ~13-15 hours (based on linear scaling)

### 4. ✅ Relative Efficiency Reference Correction
- **Created new analysis script**: `analyze_1000rep_results_corrected_ref.R`
- **Reference changed**: ps_weighted → **ps_unweighted** (Unweighted PSM)
- This aligns with theoretical expectation

## Expected Timeline

- **Submitted**: Aug 23, 2025, 18:22-18:25 EDT
- **Expected Start**: When resources available (currently pending)
- **Expected Runtime**: ~13-15 hours
- **Expected Completion**: Aug 24, morning

## Monitoring Commands

### Check Job Status
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=li_fan | grep 1000rep'
```

### Monitor Progress (once running)
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'for s in CorCor MisCor CorMis MisMis; do echo "$s:"; tail -5 /gpfs/gibbs/project/li_fan/yz2324/pooroverlap_1000rep_20250823_182203/${s}/*.out 2>/dev/null | grep -E "replicate|Completed"; done'
```

### Check Completion
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu "sacct -u \$USER --account=li_fan --format=JobID,JobName%20,State,ExitCode,Elapsed --jobs=57897693,57897704,57897706,57897719"
```

## Download and Analyze Results (When Complete)

### Download Results
```bash
for s in CorCor MisCor CorMis MisMis; do
  scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/li_fan/yz2324/pooroverlap_1000rep_20250823_182203/${s}/raw_results_1000reps_${s}_FIXED_V3.RData pooroverlap_1000rep_${s}.RData
  echo "Downloaded ${s}"
done
```

### Analyze with Corrected Reference
```bash
# Use the corrected analysis script with ps_unweighted as reference
Rscript analyze_1000rep_results_corrected_ref.R
```

## Expected Outcomes

Based on 100-rep results, we expect:

### WDSM in CorCor
- **Bias**: <1% (achieved -0.97% in 100 reps)
- **Coverage**: ~91-95%
- **Relative Efficiency**: ~7.0 (using ps_unweighted as reference)

### Theoretical Patterns
- PS methods: CorCor = CorMis ✅
- PG methods: CorCor = MisCor ✅

### With Unweighted PSM Reference
The relative efficiency values will show:
- **WDSM**: Much higher efficiency than unweighted PSM (>5x)
- **PS Full**: Also higher efficiency than unweighted PSM
- **Unweighted PSM**: Reference (1.000)

## Success Criteria

✅ All jobs complete with exit code 0:0  
✅ All 5 methods produce results  
✅ 1000 replications per scenario  
✅ WDSM bias <1% in CorCor  
✅ Coverage close to nominal 95%  
✅ Theoretical patterns confirmed  
✅ Relative efficiency correctly referenced to unweighted PSM

---

## Notes

- Jobs are queued due to CPU limits (normal for li_fan account)
- Will start when resources become available
- Based on identical configuration to successful 100-rep run
- Only change: n_reps from 100 to 1000
- Analysis script updated to use correct reference method
