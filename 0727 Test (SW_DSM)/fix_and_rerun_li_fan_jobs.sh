#!/bin/bash

echo "==========================================
Fixing and Rerunning 100-REP Jobs on LI_FAN Account
==========================================
"

# Define scenarios and remote directory
SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")
REMOTE_DIR="/gpfs/gibbs/project/li_fan/yz2324/pooroverlap_100rep_wald_20250825_184552"

echo "Remote directory: $REMOTE_DIR"
echo ""

# Upload the missing WDSM files to each scenario directory
for scenario in "${SCENARIOS[@]}"; do
    echo "Uploading missing WDSM files to $scenario..."
    
    REMOTE_SCENARIO_DIR="$REMOTE_DIR/${scenario}"
    
    # Upload WDSM files
    scp "wdsm_method2_multinomial_bootstrap_WALD.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_SCENARIO_DIR/"
    
    scp "wdsm_ci_functions.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_SCENARIO_DIR/"
    
    echo "✅ WDSM files uploaded to $scenario"
    echo ""
done

echo "==========================================
Now resubmitting jobs...
==========================================
"

# Resubmit each job
for scenario in "${SCENARIOS[@]}"; do
    echo "Resubmitting $scenario..."
    
    REMOTE_SCENARIO_DIR="$REMOTE_DIR/${scenario}"
    
    # Create new SLURM script with fixed paths
    cat > temp_slurm_${scenario}_100rep_wald_rerun.sh << EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_100wald2
#SBATCH --output=${scenario}_100rep_wald_rerun_%j.out
#SBATCH --error=${scenario}_100rep_wald_rerun_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=5G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --account=li_fan

echo "=========================================="
echo "Rerunning 100-REP ${scenario} with Normal Wald CI"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: $REMOTE_SCENARIO_DIR"
echo ""

cd $REMOTE_SCENARIO_DIR

# Verify files exist
echo "Verifying required files:"
ls -la wdsm_method2_multinomial_bootstrap_WALD.R
ls -la wdsm_ci_functions.R
ls -la compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R
echo ""

module load R/4.3.2-foss-2022b

R --no-save << 'RSCRIPT'
source("compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R")
RSCRIPT

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Upload and submit the job
    scp temp_slurm_${scenario}_100rep_wald_rerun.sh yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_SCENARIO_DIR/"
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_SCENARIO_DIR && sbatch temp_slurm_${scenario}_100rep_wald_rerun.sh" | awk '{print $4}')
    
    echo "✅ Submitted Job ID: $JOB_ID for $scenario (100 reps with Normal Wald CI)"
    
    # Clean up local temp files
    rm -f temp_slurm_${scenario}_100rep_wald_rerun.sh
    
    echo ""
done

echo "==========================================
All jobs resubmitted to li_fan account!
==========================================

To check status:
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=li_fan | grep 100wald2'

To monitor:
ssh yz2324@login2.mccleary.ycrc.yale.edu 'for s in CorCor MisCor CorMis MisMis; do echo \"\$s:\"; tail -5 $REMOTE_DIR/\${s}/*rerun*.out 2>/dev/null | grep -E \"replicate|Completed\"; done'
"
