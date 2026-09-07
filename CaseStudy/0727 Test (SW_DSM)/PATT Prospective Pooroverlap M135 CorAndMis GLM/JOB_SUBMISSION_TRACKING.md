# Job Submission Tracking - PATT M135 CorAndMis

## Submission Details
- **Submission Time**: August 11, 2025, 23:28
- **Job ID**: 57348129
- **Status**: PD (Pending)
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_20250811_2327`

## Configuration
- **Partition**: day
- **Time Limit**: 22 hours
- **CPUs**: 32 (30 for R + 2 overhead)
- **Memory**: 8GB per CPU (~256GB total)
- **Parallel Cores**: 30 (FORK cluster)

## Simulation Parameters
- **Replicates**: 1000
- **M Values**: 1, 3, 5
- **Model Specifications**: 
  - CorCor (Both PS and PGS correct)
  - MisCor (PS misspecified, PGS correct)
  - CorMis (PS correct, PGS misspecified)
  - MisMis (Both PS and PGS misspecified)
- **Methods**:
  1. DSM (Unweighted)
  2. PG (Unweighted)
  3. PS (Unweighted)
  4. PS Full (Survey-Weighted)
  5. WDSM (Survey-Weighted)
- **Bootstrap Iterations**: 200
- **Batch Size**: 100

## Total Computations
- 1000 replicates × 4 model specs × 3 M values × 5 methods = 60,000 computations

## Expected Outputs
- `comprehensive_patt_comparison_M135_CorAndMis_results.RData`
- `comprehensive_patt_comparison_M135_CorAndMis_plot.pdf`
- `comprehensive_patt_comparison_M135_CorAndMis_boxplot.pdf`
- `patt_M135_CorAndMis_57348129.out` (SLURM output)
- `patt_M135_CorAndMis_57348129.err` (SLURM error)

## Commands to Monitor

### Check Status
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j 57348129'
```

### Monitor Output
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_20250811_2327/patt_M135_CorAndMis_*.out'
```

### Download Results (when complete)
```bash
# Main results
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_20250811_2327/comprehensive_patt_comparison_M135_CorAndMis* .

# All outputs
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_20250811_2327/*.RData .
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_20250811_2327/*.csv .
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_20250811_2327/*.pdf .
```

## Notes
- The job tests model misspecification robustness by comparing scenarios where PS and/or PGS models miss the X1:X2 interaction term
- Results will help assess double robustness properties of DSM methods
- Expected runtime: 10-15 hours
