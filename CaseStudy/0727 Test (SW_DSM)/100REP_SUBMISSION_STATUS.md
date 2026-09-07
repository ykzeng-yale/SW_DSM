# 100-Replication Production Run Status

## ✅ Successfully Submitted - All Jobs Running

### Job Details

| Scenario | Job ID | Status | Runtime | Time Limit | CPUs | Expected Duration |
|----------|--------|--------|---------|------------|------|-------------------|
| **CorCor** | 57895685 | 🟢 RUNNING | 3:29 | 12:00:00 | 12 | ~1.5 hours |
| **MisCor** | 57895695 | 🟢 RUNNING | 2:44 | 12:00:00 | 12 | ~1.5 hours |
| **CorMis** | 57895701 | 🟢 RUNNING | 1:46 | 12:00:00 | 12 | ~1.5 hours |
| **MisMis** | 57895823 | 🟢 RUNNING | 0:45 | 12:00:00 | 12 | ~1.5 hours |

## Configuration

### Simulation Parameters
- **Replications**: 100 (5x more than test run)
- **Sample size**: n = 5000
- **Bootstrap**: B = 200
- **Matching ratio**: M = 5
- **True PATE**: 0.8664 (poor overlap)

### All Fixes Applied ✅
1. **Sample size**: n=5000 (corrected from 1000)
2. **Function names**: compute_wdsm_method2_ci_FIXED
3. **dsmatchATE fields**: est.ds, est.pg, est.ps  
4. **SE calculation**: sqrt(bootvar[1,1])
5. **CI calculation**: qnorm-based
6. **All 5 methods enabled**: DSM, PG, PS, PS Full, WDSM

### Remote Directory
```
/gpfs/gibbs/project/tong/yz2324/pooroverlap_100rep_20250823_153316
```

## Monitoring Commands

### Check Job Status
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong | grep 100rep'
```

### Monitor Progress
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'for s in CorCor MisCor CorMis MisMis; do echo "$s:"; tail -5 /gpfs/gibbs/project/tong/yz2324/pooroverlap_100rep_20250823_153316/${s}/*.out 2>/dev/null | grep -E "replicate|Completed"; done'
```

### Check Completion
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu "sacct -u \$USER --account=tong --format=JobID,JobName%20,State,ExitCode,Elapsed --jobs=57895685,57895695,57895701,57895823"
```

## Download Results (When Complete)

```bash
# Download all results
for s in CorCor MisCor CorMis MisMis; do
  scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pooroverlap_100rep_20250823_153316/${s}/raw_results_100reps_${s}_FIXED_V3.RData pooroverlap_100rep_${s}.RData
  echo "Downloaded ${s}"
done

# Analyze results
Rscript analyze_100rep_results.R
```

## Expected Outcomes

### Based on 20-rep test run:
- **All 5 methods should produce results** (DSM, PG, PS, PS Full, WDSM)
- **CorCor**: WDSM bias should improve with more replications (target <1%)
- **Coverage**: Should stabilize closer to nominal 95%
- **Expected patterns**:
  - PS methods: CorCor ≈ CorMis
  - PG methods: CorCor ≈ MisCor
  - MisMis: Worst for all methods

## Timeline

- **Submitted**: Aug 23, 2025, 15:33-15:39 EDT
- **Expected Completion**: ~17:00-17:30 EDT (1.5-2 hours)
- **Results Available**: Evening of Aug 23

## Notes

- Using FORK cluster with 12 cores per job
- 12-hour time limit provides ample buffer
- Based on successful 20-rep run that took ~17-19 minutes
- 100 reps expected to take ~85-95 minutes (linear scaling)

## Success Criteria

✅ All jobs complete with exit code 0:0  
✅ All 5 methods produce results  
✅ 100 replications per scenario  
✅ Results files created (raw_results_100reps_*.RData)  
✅ Expected theoretical patterns confirmed
