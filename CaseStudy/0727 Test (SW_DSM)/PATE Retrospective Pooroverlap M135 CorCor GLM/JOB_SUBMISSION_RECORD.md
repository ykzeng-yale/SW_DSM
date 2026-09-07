# Job Submission Record - Poor Overlap M135 CorAndMis GLM

## Submission Details
- **Date**: January 27, 2025
- **Initial Job ID**: 57349801 (Failed - R module issue)
- **Resubmitted Job ID**: 57428840 (Corrected version)
- **Job Name**: pate_retro_pooroverlap_m135_corandmis
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_corandmis`

## Configuration
- **Partition**: day
- **Time Limit**: 22:00:00 (22 hours)
- **CPUs**: 30 cores
- **Memory**: 8GB per CPU (240GB total)
- **Cluster Type**: FORK

## Simulation Parameters
- **Sample Size**: 5,000
- **Replicates**: 1,000
- **M Values**: 1, 3, 5
- **Bootstrap Iterations**: 200
- **Model Scenarios**: 
  - CorCor (Both PS and PGS correct)
  - MisCor (PS misspecified, PGS correct)
  - CorMis (PS correct, PGS misspecified)
  - MisMis (Both PS and PGS misspecified)

## Methods Compared
1. Unweighted DSM (Double Score Matching)
2. Unweighted PG matching (Prognostic Score)
3. Unweighted PS matching (Propensity Score)
4. Survey-weighted PS full matching (MatchIt)
5. WDSM with Multinomial Bootstrap

## Output Files
- `pate_retrospective_pooroverlap_misspec_57428840.out`
- `pate_retrospective_pooroverlap_misspec_57428840.err`
- `pate_retrospective_pooroverlap_comparison_table_misspec.csv`
- `pate_retrospective_pooroverlap_comparison_results_misspec.RData`

## Key Metrics Calculated
- **Relative Bias**: (mean(estimates) - true_pate) / abs(true_pate) [displayed as %]
- **Relative Efficiency (SE Ratio)**: mean(ses) / sd(estimates) [3 decimal places]
- **Coverage**: proportion of CIs containing true PATE [displayed as %]

## Check Status
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER'
```

## Check Output
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'ls -la /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_corandmis/*.out'
```

## Download Results
```bash
./check_and_download_results.sh
```

## Troubleshooting Notes
- **Initial Issue**: Job 57349801 failed due to R module version 4.3.0 not being available
- **Solution**: Changed `module load R/4.3.0` to `module load R` (loads default R version)
- **Additional Fix**: Uploaded `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData` to server
- **Result**: Successfully resubmitted as job 57428840

## Expected Differences from Good Overlap
Under poor overlap conditions, we expect:
- Higher bias across all methods
- Reduced coverage rates (likely below nominal 95%)
- Increased standard errors
- Greater sensitivity to model misspecification
- Potentially more failures in matching procedures
