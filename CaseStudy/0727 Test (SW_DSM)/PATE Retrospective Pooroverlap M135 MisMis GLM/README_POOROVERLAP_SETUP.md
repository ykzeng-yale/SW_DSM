# PATE Retrospective Poor Overlap M135 CorAndMis GLM Setup

## Overview
This folder contains the comprehensive comparison of matching methods under **poor overlap** conditions with model misspecification scenarios.

## Key Changes from Good Overlap Version

### 1. Data Generation
- **Data File**: Now uses `SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData`
- **Overlap Characteristics**:
  - Control group mean PS: ~0.156 (shifted left)
  - Treated group mean PS: ~0.666 (shifted right)
  - Clear separation between treatment groups (poor overlap)

### 2. Updated Files
- `compare_methods_pate_retrospective_mccleary.R`: Main comparison script updated to load poor overlap data
- `run_comparison_mccleary_optimized.sh`: SLURM script updated with poor overlap paths
- `submit_to_mccleary.sh`: Submission script updated for poor overlap
- `check_and_download_results.sh`: Download script updated with correct paths

### 3. Output Files
All output files now have "pooroverlap" in their names:
- `pate_retrospective_pooroverlap_comparison_table_misspec.csv`
- `pate_retrospective_pooroverlap_comparison_results_misspec.RData`
- `pate_retrospective_pooroverlap_misspec_*.out`
- `pate_retrospective_pooroverlap_misspec_*.err`

## Simulation Configuration
- **Sample size**: 5,000
- **Replicates**: 1,000
- **M values**: 1, 3, 5 (number of matches)
- **Bootstrap iterations**: 200
- **Model scenarios**: 
  - CorCor: Both PS and PGS correct (include X1:X2 interaction)
  - MisCor: PS misspecified (no X1:X2), PGS correct
  - CorMis: PS correct, PGS misspecified (no X1:X2)
  - MisMis: Both PS and PGS misspecified

## Methods Compared
1. Unweighted DSM (Double Score Matching)
2. Unweighted PG matching (Prognostic Score)
3. Unweighted PS matching (Propensity Score)
4. Survey-weighted PS full matching (MatchIt)
5. WDSM with Multinomial Bootstrap

## HPC Submission
```bash
# To submit to McCleary HPC:
./submit_to_mccleary.sh

# To check status and download results:
./check_and_download_results.sh
```

## Expected Runtime
- Approximately 22 hours on McCleary HPC with 30 cores
- Uses FORK cluster type for better stability
- 8GB memory per CPU

## Remote Directory
`/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_corandmis`

## Testing
A local test script is provided to verify the poor overlap configuration:
```bash
Rscript test_pooroverlap_local.R
```

## Notes
- Poor overlap scenarios are expected to show:
  - Higher bias for all methods
  - Reduced coverage rates
  - Increased standard errors
  - Greater sensitivity to model misspecification
- Results can be compared with good overlap version to assess the impact of overlap quality
