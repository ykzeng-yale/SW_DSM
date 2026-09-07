# Job Submission Log - Poor Overlap M135 CorAndMis

## Submission Details
- **Date/Time**: August 11, 2025, 23:55
- **Job ID**: 57349802
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_Poor_20250811_2355`

## Configuration
- **Data**: Poor Overlap (SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData)
- **Model Specifications**: CorCor, MisCor, CorMis, MisMis (4 scenarios)
- **M Values**: 1, 3, 5 neighbors
- **Replicates**: 1000 per scenario
- **Bootstrap**: 200 iterations
- **Methods**: 
  - DSM (Unweighted)
  - PG (Unweighted)
  - PS (Unweighted)
  - PS Full (Survey-Weighted)
  - WDSM V1 (Survey-Weighted)

## HPC Settings
- **Partition**: day
- **Time Limit**: 22 hours
- **CPUs**: 32 (30 for R + 2 overhead)
- **Memory**: 8GB per CPU (~256GB total)
- **Cluster Type**: FORK

## Commands to Monitor

Check status:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j 57349802'
```

Monitor output:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_Poor_20250811_2355/patt_M135_CorAndMis_Poor_*.out'
```

Download results:
```bash
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_Poor_20250811_2355/comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap* .
```

## Notes
- This job tests performance under poor overlap conditions
- Relative bias, coverage, and relative efficiency are calculated for all combinations
- PS (Unweighted) is used as the reference method for relative efficiency
