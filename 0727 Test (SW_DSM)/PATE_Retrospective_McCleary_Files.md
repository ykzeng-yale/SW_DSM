# PATE Retrospective McCleary Files Summary

## Files Created for McCleary HPC Submission

### 1. **compare_methods_pate_retrospective_mccleary.R**
- Main R script adapted for McCleary HPC
- Key changes:
  - FORK cluster type for stability
  - Functions sourced inside workers
  - `match.data()` instead of `match_data()` 
  - Timeout protection (5 minutes per replicate)
  - Memory management with `gc()`
  - Batch processing (batch_size=100)

### 2. **submit_pate_retrospective_mccleary.sh**
- SLURM submission script
- Configuration:
  - 22 CPUs (20 for R + 2 overhead)
  - 8GB per CPU (~176GB total)
  - 8-hour time limit
  - `day` partition

### 3. **mccleary_submit_retrospective.sh**
- Convenient upload and submission script
- Handles:
  - Creating timestamped remote directory
  - Uploading all required files
  - Submitting the job
  - Printing useful monitoring commands
- Usage: `./mccleary_submit_retrospective.sh`

### 4. **test_pate_retrospective_local.R**
- Local test script with reduced parameters
- Tests with 10 replicates, 2 cores, 50 bootstrap iterations
- Run before submitting to McCleary

### 5. **PATE_Retrospective_McCleary_Changes.md**
- Documentation of all changes made for HPC compatibility
- References relevant memories for context

## Required Files to Upload

The submission script will automatically upload:
1. `compare_methods_pate_retrospective_mccleary.R` (main script)
2. `wdsm_method2_multinomial_bootstrap.R` (WDSM functions)
3. `wdsm_ci_functions.R` (WDSM helper functions)
4. `SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData` (population data)
5. `dsmatch-master/` directory (dsmatch package)
6. `submit_pate_retrospective_mccleary.sh` (SLURM script)

## Workflow

1. **Local Test** (optional but recommended):
   ```bash
   Rscript test_pate_retrospective_local.R
   ```

2. **Submit to McCleary**:
   ```bash
   chmod +x mccleary_submit_retrospective.sh
   ./mccleary_submit_retrospective.sh
   ```

3. **Monitor Progress**: Use commands printed by submission script

4. **Download Results**: When complete, download:
   - `pate_retrospective_comparison_results_mccleary.RData`
   - `pate_retrospective_comparison_plot_mccleary.pdf`
   - `pate_retrospective_comparison_table_mccleary.csv`
   - `pate_retrospective_bias_variance_plot_mccleary.pdf`

## Key McCleary-Specific Adaptations

Based on memories [[memory:5088944]] and [[memory:5045225]]:

1. **FORK > PSOCK**: Critical for avoiding connection errors
2. **20 cores**: Optimal balance of speed and stability
3. **Function sourcing**: Inside workers for PSOCK fallback compatibility
4. **Batch processing**: Prevents memory issues with large simulations
5. **Proper directory**: Uses `/gpfs/gibbs/project/tong/yz2324/`