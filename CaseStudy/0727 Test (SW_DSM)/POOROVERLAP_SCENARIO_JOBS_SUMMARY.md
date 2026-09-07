# Poor Overlap Scenario Jobs - Submission Summary

## Date: January 27, 2025

## Overview
Successfully split the comprehensive comparison into 4 separate jobs, one for each model specification scenario. This allows parallel execution and faster completion.

## Submitted Jobs

### 1. CorCor Scenario
- **Job ID**: 57548318
- **Job Name**: pate_pooroverlap_CorCor
- **Description**: Both PS and PGS correct (with X1:X2 interaction)
- **Status**: PENDING (Priority queue)
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_CorCor`
- **Output Files**:
  - `pate_retrospective_pooroverlap_CorCor_57548318.out`
  - `pate_retrospective_pooroverlap_comparison_table_CorCor.csv`
  - `pate_retrospective_pooroverlap_comparison_results_CorCor.RData`

### 2. MisCor Scenario
- **Job ID**: 57548321
- **Job Name**: pate_pooroverlap_MisCor
- **Description**: PS misspecified (no X1:X2), PGS correct
- **Status**: PENDING (Priority queue)
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_MisCor`
- **Output Files**:
  - `pate_retrospective_pooroverlap_MisCor_57548321.out`
  - `pate_retrospective_pooroverlap_comparison_table_MisCor.csv`
  - `pate_retrospective_pooroverlap_comparison_results_MisCor.RData`

### 3. CorMis Scenario
- **Job ID**: 57548324
- **Job Name**: pate_pooroverlap_CorMis
- **Description**: PS correct (has X1:X2), PGS misspecified (no X1:X2)
- **Status**: PENDING (Priority queue)
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_CorMis`
- **Output Files**:
  - `pate_retrospective_pooroverlap_CorMis_57548324.out`
  - `pate_retrospective_pooroverlap_comparison_table_CorMis.csv`
  - `pate_retrospective_pooroverlap_comparison_results_CorMis.RData`

### 4. MisMis Scenario
- **Job ID**: 57548327
- **Job Name**: pate_pooroverlap_MisMis
- **Description**: Both PS and PGS misspecified (no X1:X2)
- **Status**: PENDING (Priority queue)
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_MisMis`
- **Output Files**:
  - `pate_retrospective_pooroverlap_MisMis_57548327.out`
  - `pate_retrospective_pooroverlap_comparison_table_MisMis.csv`
  - `pate_retrospective_pooroverlap_comparison_results_MisMis.RData`

## Configuration (All Jobs)
- **Partition**: day
- **Time Limit**: 22:00:00 (22 hours)
- **CPUs**: 30 cores (FORK cluster)
- **Memory**: 8GB per CPU (240GB total)
- **Simulation Parameters**:
  - Sample size: 5,000
  - Replicates: 1,000
  - M values: 1, 3, 5
  - Bootstrap iterations: 200

## Monitoring Commands

### Check All Jobs Status
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u $USER | grep pate_poo'
```

### Check Individual Job Output
```bash
# CorCor
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_CorCor/pate_retrospective_pooroverlap_CorCor_57548318.out'

# MisCor
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_MisCor/pate_retrospective_pooroverlap_MisCor_57548321.out'

# CorMis
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_CorMis/pate_retrospective_pooroverlap_CorMis_57548324.out'

# MisMis
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_MisMis/pate_retrospective_pooroverlap_MisMis_57548327.out'
```

### Download Results When Complete
```bash
# Download all results at once
for scenario in CorCor MisCor CorMis MisMis; do
  echo "Downloading $scenario results..."
  rsync -avz yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_$scenario/*.csv .
  rsync -avz yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_$scenario/*.RData .
done
```

## Expected Completion
- All 4 jobs running in parallel should complete within 22 hours
- Total computational advantage: 4x speedup compared to single job
- Results will show the impact of model misspecification under poor overlap conditions

## Local Folders Created
1. `PATE Retrospective Pooroverlap M135 CorCor GLM/`
2. `PATE Retrospective Pooroverlap M135 MisCor GLM/`
3. `PATE Retrospective Pooroverlap M135 CorMis GLM/`
4. `PATE Retrospective Pooroverlap M135 MisMis GLM/`

## Notes
- Each scenario runs independently, allowing for parallel execution
- Results can be compared across scenarios to assess the impact of model misspecification
- Poor overlap conditions are expected to amplify the differences between methods
- Coverage rates likely to be below nominal 95% due to poor overlap
