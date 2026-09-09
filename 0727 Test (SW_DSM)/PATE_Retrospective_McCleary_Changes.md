# PATE Retrospective Comparison - McCleary HPC Adaptation

## Key Changes Made for McCleary Compatibility

Based on the memories [[memory:5088944]] and [[memory:5045225]], the following critical changes were made to adapt the retrospective PATE comparison script for McCleary HPC:

### 1. **Parallel Processing Configuration**
- **Changed to FORK cluster type** (critical for stability):
  ```r
  cl <- makeCluster(n_cores, type = "FORK", outfile = "parallel_log.txt")
  ```
- Set to 20 cores (optimal for McCleary)
- Added batch processing with `batch_size = 100`
- Included `.errorhandling = 'pass'` to continue despite individual failures

### 2. **Function Sourcing**
- Added sourcing of all dsmatch functions inside the worker function
- Also sourced WDSM functions inside workers
- This ensures compatibility if FORK is unavailable and system falls back to PSOCK

### 3. **MatchIt Compatibility**
- Changed `match_data()` to `match.data()` for version compatibility:
  ```r
  md_sw <- match.data(m_ps_sw)  # Use match.data for compatibility with McCleary
  ```

### 4. **Timeout Protection**
- Added `R.utils::withTimeout()` with 5-minute timeout per replicate
- Prevents hanging jobs from blocking the entire simulation

### 5. **Memory Management**
- Added `gc()` calls before and after each replicate
- Helps manage memory in long-running simulations

### 6. **Error Handling**
- Wrapped entire replicate in try-catch with proper cleanup
- Added informative error messages with replicate numbers

### 7. **SLURM Configuration**
Based on [[memory:4996791]]:
- 22 CPUs (20 for R + 2 overhead)
- 8GB per CPU (~176GB total)
- `day` partition for faster queue access
- 8-hour time limit for 1000 replicates

### 8. **File Organization**
- Created timestamped directories for each run
- Uses correct McCleary directory: `/gpfs/gibbs/project/tong/yz2324/`
- Comprehensive file upload including all dependencies

## Usage

1. **Make submission script executable**:
   ```bash
   chmod +x mccleary_submit_retrospective.sh
   ```

2. **Submit to McCleary**:
   ```bash
   ./mccleary_submit_retrospective.sh
   ```

3. **Monitor progress**: Follow the commands printed by the submission script

## Expected Performance

Based on the prospective sampling reference:
- 1000 replicates should complete in 4-6 hours
- Nearly 100% success rate with FORK cluster
- Minimal connection errors

## Key Differences from Local Version

1. **Parallel backend**: FORK instead of default
2. **Function sourcing**: Inside workers for PSOCK compatibility
3. **MatchIt function**: `match.data()` instead of `match_data()`
4. **Resource limits**: Optimized for HPC environment
5. **Error handling**: More robust for distributed computing