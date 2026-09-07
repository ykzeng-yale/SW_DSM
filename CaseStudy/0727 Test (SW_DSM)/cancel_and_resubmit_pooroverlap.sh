#!/bin/bash

echo "============================================================"
echo "Canceling and Resubmitting Poor Overlap Jobs with Fixed WDSM"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"

# Job IDs to cancel (from previous submission)
OLD_JOB_IDS="57548318 57548321 57548324 57548327"

echo ""
echo "Step 1: Canceling old jobs..."
echo "============================================================"
for job_id in $OLD_JOB_IDS; do
    echo "Canceling job $job_id..."
    ssh $SERVER "scancel $job_id 2>/dev/null"
done

echo ""
echo "Step 2: Uploading fixed WDSM scripts..."
echo "============================================================"

# Scenarios to update
scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

for scenario in "${scenarios[@]}"; do
    echo "Uploading fixed scripts for $scenario..."
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_$scenario"
    
    # Upload the fixed WDSM files
    rsync -avz "$LOCAL_DIR/wdsm_method2_multinomial_bootstrap.R" $SERVER:$REMOTE_DIR/
    rsync -avz "$LOCAL_DIR/wdsm_ci_functions.R" $SERVER:$REMOTE_DIR/
    rsync -avz "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary.R" $SERVER:$REMOTE_DIR/
done

echo ""
echo "Step 3: Resubmitting jobs with fixed code..."
echo "============================================================"

# Track new job IDs
new_job_ids=""

for scenario in "${scenarios[@]}"; do
    echo "Submitting $scenario scenario..."
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_$scenario"
    
    # Submit job
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_optimized.sh" 2>&1)
    job_id=$(echo $job_output | grep -o '[0-9]\+' | tail -1)
    new_job_ids="$new_job_ids $job_id"
    echo "  $scenario submitted with Job ID: $job_id"
done

echo ""
echo "============================================================"
echo "All jobs resubmitted successfully with fixed WDSM!"
echo "============================================================"
echo "New Job IDs: $new_job_ids"
echo ""
echo "Key fixes applied:"
echo "  1. WDSM now properly accepts use_interaction_ps and use_interaction_pg flags"
echo "  2. No more hardcoded X1:X2 interactions in bootstrap functions"
echo "  3. Each scenario will use correct model specifications:"
echo "     - CorCor: Both PS and PGS with interaction"
echo "     - MisCor: PS without interaction, PGS with interaction"
echo "     - CorMis: PS with interaction, PGS without interaction"
echo "     - MisMis: Both PS and PGS without interaction"
echo ""
echo "To check status:"
echo "ssh $SERVER 'squeue -u \$USER | grep pate_poo'"
echo "============================================================"
