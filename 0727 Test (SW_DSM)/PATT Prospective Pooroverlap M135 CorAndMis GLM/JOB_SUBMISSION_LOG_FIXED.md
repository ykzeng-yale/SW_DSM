# Job Submission Log - Poor Overlap M135 CorAndMis (FIXED)

## Previous Failed Job
- **Job ID**: 57349802 (FAILED - all methods due to WDSM function signature issue)
- **Issue**: WDSM function called with ps_formula/pgs_formula parameters that don't exist

## Fixed Job Submission
- **Date/Time**: August 12, 2025, 15:52
- **Job ID**: 57432401  
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_Poor_fixed`

## Fix Applied:
1. Removed invalid `ps_formula` and `pgs_formula` parameters from WDSM call
2. Prepared X matrix with/without interaction based on model specification:
   - CorCor/CorMis: X includes interaction term (7 columns)
   - MisCor/MisMis: X without interaction term (6 columns)
3. WDSM now fits models on ALL columns of provided X matrix

## Configuration (Same as before)
- **Data**: Poor Overlap (SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData)
- **Model Specifications**: CorCor, MisCor, CorMis, MisMis (4 scenarios)
- **M Values**: 1, 3, 5 neighbors
- **Replicates**: 1000 per scenario
- **Bootstrap**: 200 iterations
- **Methods**: DSM, PG, PS (unweighted) + PS Full, WDSM (survey-weighted)

## HPC Settings
- **Partition**: day
- **Time Limit**: 22 hours
- **CPUs**: 32 (30 for R + 2 overhead)
- **Memory**: 8GB per CPU (~256GB total)
- **Cluster Type**: FORK

## Commands to Monitor

Check status:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j 57432401'
```

Monitor output:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_Poor_fixed/patt_M135_CorAndMis_Poor_*.out'
```

Download results:
```bash
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_Poor_fixed/comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap* .
```

## Notes
- This resubmission fixes the WDSM function call issue
- The poor overlap data is challenging but should work with proper matching algorithms
- Expected completion: 10-15 hours if all methods work properly
