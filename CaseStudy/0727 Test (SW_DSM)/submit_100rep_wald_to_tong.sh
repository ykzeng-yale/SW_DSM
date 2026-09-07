#!/bin/bash

# Submit 100-rep jobs with Normal Wald CI WDSM to tong account

echo "==========================================
Submitting 100-REP Jobs with Normal Wald CI to TONG Account
==========================================
"

# Define scenarios
SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")

# Create remote directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pooroverlap_100rep_wald_${TIMESTAMP}"

echo "Remote directory: $REMOTE_DIR"
echo ""

# Create remote directory
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

for scenario in "${SCENARIOS[@]}"; do
    echo "Processing $scenario..."
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_SCENARIO_DIR="$REMOTE_DIR/${scenario}"
    
    # Create scenario directory on remote
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_SCENARIO_DIR"
    
    # Upload comparison script
    scp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_SCENARIO_DIR/"
    
    # Upload WDSM files with Normal Wald CI
    scp "wdsm_method2_multinomial_bootstrap_WALD.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_SCENARIO_DIR/"
    scp "wdsm_ci_functions.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_SCENARIO_DIR/"
    
    # Upload data file
    scp "SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_SCENARIO_DIR/"
    
    # Upload dsmatch-master folder
    tar -czf dsmatch-master.tar.gz dsmatch-master/
    scp dsmatch-master.tar.gz yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_SCENARIO_DIR/"
    ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_SCENARIO_DIR && tar -xzf dsmatch-master.tar.gz && rm dsmatch-master.tar.gz"
    rm dsmatch-master.tar.gz
    
    # Create SLURM script
    cat > temp_slurm_${scenario}_100rep_wald.sh << EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_100wald
#SBATCH --output=${scenario}_100rep_wald_%j.out
#SBATCH --error=${scenario}_100rep_wald_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=5G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --account=tong

echo "=========================================="
echo "Starting 100-REP ${scenario} with Normal Wald CI"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: $REMOTE_SCENARIO_DIR"
echo ""
echo "Configuration:"
echo "- Sample size: n=5000"
echo "- Scenario: ${scenario}"
echo "- Replicates: 100"
echo "- Bootstrap: 200"
echo "- M: 5"
echo "- CI Method: Normal Wald (not quantile)"
echo "- Account: tong"
echo ""

cd $REMOTE_SCENARIO_DIR

module load R/4.3.2-foss-2022b

R --no-save << 'RSCRIPT'
source("compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R")
RSCRIPT

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Submit the job
    scp temp_slurm_${scenario}_100rep_wald.sh yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_SCENARIO_DIR/"
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_SCENARIO_DIR && sbatch temp_slurm_${scenario}_100rep_wald.sh" | awk '{print $4}')
    
    echo "✅ Submitted Job ID: $JOB_ID for $scenario (100 reps with Normal Wald CI)"
    
    # Clean up local temp files
    rm -f temp_slurm_${scenario}_100rep_wald.sh
    
    echo ""
done

echo "==========================================
All 100-REP jobs with Normal Wald CI submitted to tong account!
==========================================

Remote directory: $REMOTE_DIR

Configuration:
✅ Replications: 100
✅ Time limit: 23 hours (day partition)
✅ Account: tong
✅ All 5 methods enabled
✅ WDSM uses Normal Wald CI (not quantile)
✅ Correct retrospective sampling
✅ Correct sample size (n=5000)
✅ No M parameter passed to dsmatchATE

Expected runtime: ~80-90 minutes per scenario

To check status:
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep 100wald'

To monitor progress:
ssh yz2324@login2.mccleary.ycrc.yale.edu 'for s in CorCor MisCor CorMis MisMis; do echo \"\$s:\"; tail -5 $REMOTE_DIR/\${s}/*.out 2>/dev/null | grep -E \"replicate|Completed\"; done'

To download results when complete:
for s in CorCor MisCor CorMis MisMis; do 
  scp yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/\${s}/raw_results_100reps_\${s}_WALD_CI.RData pooroverlap_100rep_wald_\${s}.RData
  echo \"Downloaded \${s}\"
done
"
