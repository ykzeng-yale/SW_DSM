# Poor Overlap Submission Summary

## Submission Details
- **Job ID**: 57117031
- **Submitted**: 2025-08-05 10:56 AM
- **Status**: Running
- **Node**: r813u03n12
- **Remote Directory**: `/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_20250805_1056/`

## Configuration
- **Scenario**: Poor Overlap (limited overlap between treatment/control groups)
- **Sample Size**: 5000 (retrospective sampling)
- **Replicates**: 1000
- **Bootstrap Iterations**: 200
- **Matches per Unit**: M=5
- **CPUs**: 22 (20 for R + 2 overhead)
- **Memory**: 8GB per CPU (~176GB total)
- **Cluster Type**: FORK
- **Expected Runtime**: 1.5-2 hours

## Methods Being Compared
1. **DSM (Unweighted)** - Double Score Matching
2. **PG (Unweighted)** - Prognostic Score Matching  
3. **PS (Unweighted)** - Propensity Score Matching
4. **PS Full (Survey-Weighted)** - MatchIt with survey weights
5. **WDSM (Multinomial Bootstrap)** - Weighted DSM with retrospective sampling

## Key Features
- All methods use correct GLM specification (`model.ps = "logit"` with interaction)
- WDSM uses `quasibinomial` for survey-weighted PS estimation
- Poor overlap data characteristics:
  - Control group mean propensity score: 0.156
  - Treated group mean propensity score: 0.666
  - Shows significant separation between treatment groups

## Commands to Monitor Progress

Check job status:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j 57117031'
```

Monitor output:
```bash
ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_20250805_1056/pate_retro_*.out'
```

Download results when complete:
```bash
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_20250805_1056/pate_retrospective_*.RData .
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_20250805_1056/pate_retrospective_*.pdf .
scp -r yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retro_pooroverlap_20250805_1056/pate_retrospective_*.csv .
```