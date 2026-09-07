# ✅ PROPERLY_SOURCED Jobs Successfully Submitted!

## Problem Fixed
The critical bug was identified: the WDSM scripts were missing the source for `wdsm_method2_multinomial_bootstrap.R`, which contains the `compute_wdsm_method2_ci` function.

## New Submission Details

### Job IDs (TONG Account)
| Scenario | Job ID    | Status | Name            |
|----------|-----------|--------|-----------------|
| CorCor   | 57774535  | PD     | Poor_CorCor_PROP |
| MisCor   | 57774537  | PD     | Poor_MisCor_PROP |
| CorMis   | 57774543  | PD     | Poor_CorMis_PROP |
| MisMis   | 57774544  | PD     | Poor_MisMis_PROP |

### Directory Structure on Server
```
/gpfs/gibbs/project/tong/yz2324/
├── pooroverlap_properly_sourced_CorCor_100reps/
├── pooroverlap_properly_sourced_MisCor_100reps/
├── pooroverlap_properly_sourced_CorMis_100reps/
└── pooroverlap_properly_sourced_MisMis_100reps/
```

### Each Directory Contains
✅ `compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R`
✅ `wdsm_method2_multinomial_bootstrap.R` (**NOW INCLUDED - FIX**)
✅ `wdsm_ci_functions.R`
✅ `dsmatch-master/` (all required functions)
✅ `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData`

## Key Fixes Applied

1. **Added Missing Source**: 
   ```r
   source("wdsm_method2_multinomial_bootstrap.R")  # NOW INCLUDED
   source("wdsm_ci_functions.R")
   ```

2. **Clean Directory Names**: No spaces in directory names to avoid upload issues

3. **Complete File Package**: All dependencies in each working directory

## Expected Results

With the proper WDSM source files:
- **CorCor**: Should achieve <1% bias, ~95% coverage (vs previous -3% bias, 79% coverage)
- **Model misspecification patterns**: Should work correctly
- **All methods**: Should produce valid results

## Job Configuration
- **Partition**: day (22 hour limit)
- **CPUs**: 22 cores per job
- **Memory**: 8GB per CPU
- **Replicates**: 100
- **Bootstrap**: 200 iterations

## Monitor Progress

```bash
# Check job status
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER --account=tong | grep Poor_'

# Download results when complete
for s in CorCor MisCor CorMis MisMis; do
  scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pooroverlap_properly_sourced_${s}_100reps/*.csv pooroverlap_PROPER_${s}.csv
done
```

## Timeline
- **Submission Time**: Aug 20, 2025, 14:01 EST
- **Expected Completion**: ~2-3 hours per job
- **Current Status**: PD (Pending) - waiting for resources

The jobs are queued and will start when resources become available!
