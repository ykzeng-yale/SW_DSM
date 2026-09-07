# PATT Comparison McCleary HPC Submission Guide

## Overview
This guide explains how to submit the comprehensive PATT comparison script to Yale's McCleary HPC cluster.

## Key Adaptations for HPC

### 1. **Parallel Processing Changes**
- **FORK cluster type** instead of default PSOCK for better stability
- **20 cores** (optimal for McCleary based on memory [[memory:5088944]])
- **Batch processing** with size 100 to manage memory
- **Source functions inside workers** for PSOCK compatibility

### 2. **Function Compatibility**
- Changed `match_data()` to `match.data()` for older MatchIt versions
- Added explicit sourcing of all dsmatch functions (no devtools::load_all)
- Added R.utils for timeout protection

### 3. **Error Handling**
- Timeout protection (5 minutes per replicate)
- `.errorhandling = 'pass'` to continue despite individual failures
- Memory management with `gc()` calls

### 4. **Resource Allocation**
- 22 CPUs (20 for R + 2 overhead)
- 8GB per CPU (~176GB total)
- 8 hour time limit
- day partition

## Files Created

1. **`comprehensive_patt_comparison_mccleary.R`** - Main R script adapted for HPC
2. **`run_patt_comparison_mccleary.sh`** - SLURM submission script
3. **`submit_patt_comparison_mccleary.sh`** - Automated submission helper
4. **`mccleary_patt_quick_commands.sh`** - Quick command shortcuts

## How to Submit

### Option 1: Automated Submission
```bash
./submit_patt_comparison_mccleary.sh
```
This will:
- Create timestamped directory
- Upload all required files
- Submit the job
- Display job ID and monitoring commands

### Option 2: Manual Steps
```bash
# 1. Upload files
./mccleary_patt_quick_commands.sh upload

# 2. SSH to McCleary
ssh yz2324@login2.mccleary.ycrc.yale.edu

# 3. Navigate to directory
cd /gpfs/gibbs/project/tong/yz2324/patt_comparison_YYYYMMDD_HHMM

# 4. Submit job
sbatch run_patt_comparison_mccleary.sh
```

### Option 3: Quick Commands
```bash
# Full automated submission
./mccleary_patt_quick_commands.sh all

# Check status
./mccleary_patt_quick_commands.sh status

# Download results when done
./mccleary_patt_quick_commands.sh download
```

## Expected Output

The script will generate:
- `comprehensive_patt_comparison_results.RData` - All simulation results
- `comprehensive_patt_comparison_table.csv` - Summary statistics table
- `comprehensive_patt_comparison_plot.pdf` - Comparison plots
- `comprehensive_patt_comparison_boxplot.pdf` - Distribution boxplots
- `patt_comparison_*.out` - SLURM output log
- `patt_comparison_*.err` - SLURM error log
- `parallel_log.txt` - Parallel processing log

## Monitoring the Job

```bash
# Check job status
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u yz2324'

# Watch output in real-time
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/patt_comparison_*/patt_comparison_*.out'

# Check parallel log
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/patt_comparison_*/parallel_log.txt'
```

## Expected Runtime
- **1000 replicates**: 60-90 minutes
- **Average per replicate**: ~4-5 seconds

## Troubleshooting

### If job fails early:
1. Check error log: `patt_comparison_*.err`
2. Common issues:
   - Module not loaded → Check R module name
   - Out of memory → Reduce batch size or cores
   - Package not found → Install missing packages

### If some replicates fail:
- Normal to have a few failures with 1000 replicates
- Check summary output for failure rates by method
- Successful replicates will still be analyzed

## Key Differences from Local Version

1. **Parallel setup**: FORK cluster with explicit parameters
2. **Function sourcing**: All functions sourced explicitly
3. **Timeout protection**: Prevents hanging replicates
4. **Memory management**: Aggressive garbage collection
5. **Error handling**: Continue despite individual failures

## Notes

- WDSM function automatically handles interaction terms internally
- Unweighted methods use GLM logit for PS estimation
- Survey-weighted methods use quasibinomial family
- Results include empirical variance and relative efficiency analysis