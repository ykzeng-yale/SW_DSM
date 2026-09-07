#!/bin/bash

# Master script to submit all 4 scenario jobs to McCleary HPC

echo "============================================================"
echo "Submitting All Poor Overlap Scenario Jobs to McCleary"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"

# Scenarios to submit
scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

# Track job IDs
job_ids=""

for scenario in "${scenarios[@]}"; do
    echo ""
    echo "============================================================"
    echo "Submitting $scenario scenario..."
    echo "============================================================"
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_$scenario"
    
    # Step 1: Create remote directory
    echo "Creating remote directory for $scenario..."
    ssh $SERVER "mkdir -p $REMOTE_DIR"
    
    # Step 2: Upload files
    echo "Uploading files for $scenario..."
    rsync -avz --progress \
      --exclude="*.RData" \
      --exclude="*.pdf" \
      --exclude="*.csv" \
      --exclude="*.txt" \
      --exclude="*.md" \
      --exclude="*.log" \
      --exclude="*.out" \
      --exclude="*.err" \
      "$LOCAL_DIR/" $SERVER:$REMOTE_DIR/
    
    # Step 3: Upload data file
    echo "Uploading data file for $scenario..."
    rsync -avz "$LOCAL_DIR/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" $SERVER:$REMOTE_DIR/
    
    # Step 4: Submit job
    echo "Submitting job for $scenario..."
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_optimized.sh")
    job_id=$(echo $job_output | grep -oP '\d+')
    job_ids="$job_ids $job_id"
    echo "Job submitted with ID: $job_id"
done

echo ""
echo "============================================================"
echo "All jobs submitted successfully!"
echo "============================================================"
echo "Job IDs: $job_ids"
echo ""
echo "To check status of all jobs:"
echo "ssh $SERVER 'squeue -u \$USER'"
echo ""
echo "To check specific scenario output:"
for scenario in "${scenarios[@]}"; do
    echo "  $scenario: ssh $SERVER 'ls -la /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_$scenario/*.out'"
done
echo "============================================================"
