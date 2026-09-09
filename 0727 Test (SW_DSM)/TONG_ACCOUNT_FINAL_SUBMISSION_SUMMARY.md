# Tong Account FINAL 100-Rep Submission Summary

## Submission Details
**Date**: January 2025  
**Account**: tong (FairShare: 0.333 - higher priority) [[memory:6394261]]  
**Partition**: day (22-hour limit)  
**Cores**: 20  
**Memory**: 8GB per CPU (160GB total)  

## Job IDs Submitted

| Scenario | Job ID | Status |
|----------|--------|--------|
| CorCor | 57731445 | Submitted |
| MisCor | 57731448 | Submitted |
| CorMis | 57731487 | Submitted |
| MisMis | 57731492 | Submitted |

## Implementation Details

### Key Fixes Applied
1. **DSM Method**: Uses `X` for PS model, `model.pg='linpred'` with `lp.pg` for PG model
2. **Truly Independent Specifications**: PS and PG models can have different interaction specifications
3. **No Model Type Changes**: Always uses `model.ps = "logit"`

### Scenario Specifications

| Scenario | PS Model | PG Model | Expected Performance |
|----------|----------|----------|---------------------|
| CorCor | Has X1:X2 | Has X1:X2 | WDSM <1% bias, ~95% coverage |
| MisCor | No X1:X2 | Has X1:X2 | PS methods degraded |
| CorMis | Has X1:X2 | No X1:X2 | PG methods degraded |
| MisMis | No X1:X2 | No X1:X2 | All methods degraded |

## Files Deployed
- `compare_methods_pate_retrospective_mccleary_M5_100reps.R` (FINAL version)
- `wdsm_method2_multinomial_bootstrap.R` (with interaction flags)
- `wdsm_ci_functions.R` (with interaction flags)
- `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData`

## Monitoring Commands

Check job status:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong | grep FINAL'
```

Check all tong account jobs:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong'
```

Check specific job details:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'scontrol show job 57731445'  # CorCor
ssh yz2324@login2.mccleary.ycrc.yale.edu 'scontrol show job 57731448'  # MisCor  
ssh yz2324@login2.mccleary.ycrc.yale.edu 'scontrol show job 57731487'  # CorMis
ssh yz2324@login2.mccleary.ycrc.yale.edu 'scontrol show job 57731492'  # MisMis
```

Check output files when running:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_CorCor_100reps_FINAL/*.out'
```

Check results when complete:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'ls -la /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_100reps_FINAL/*.csv'
```

Download results:
```bash
for scenario in CorCor MisCor CorMis MisMis; do
  scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_100reps_FINAL/*.csv .
  scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_100reps_FINAL/*.RData .
done
```

## Expected Runtime
- Each job: ~30-45 minutes (100 reps, M=5, 20 cores)
- Total: All should complete within 1 hour

## Output Files
Each scenario will generate:
- `pate_retrospective_pooroverlap_comparison_table_M5_100reps_[Scenario].csv`
- `pate_retrospective_pooroverlap_comparison_results_M5_100reps_[Scenario].RData`
- Log files: `.out` and `.err`
