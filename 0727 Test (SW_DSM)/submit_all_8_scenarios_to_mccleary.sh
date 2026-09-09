#!/bin/bash

# Script to submit all 8 scenario jobs to McCleary HPC
# 4 full (M=1,3,5) to week partition with 7-day timeout
# 4 reduced (M=5 only) to day partition with 22-hour timeout

SERVER="login2.mccleary.ycrc.yale.edu"
USER="yz2324"
LOCAL_DIR="/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Code Experiment/0727 Test (SW_DSM)"

echo "============================================================"
echo "Uploading files to McCleary for all 8 scenarios..."
echo "============================================================"

# Upload M=1,3,5 versions (week partition)
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m135_${scenario_lower}"
    echo "------------------------------------------------------------"
    echo "Uploading M135 ${scenario} scenario..."
    ssh "$USER@$SERVER" "mkdir -p $REMOTE_DIR"
    scp -r "${LOCAL_DIR}/PATE Retrospective Goodoverlap M135 ${scenario} GLM/"* "$USER@$SERVER:$REMOTE_DIR/"
    echo "Uploading population data for M135 ${scenario}..."
    scp "${LOCAL_DIR}/SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData" "$USER@$SERVER:$REMOTE_DIR/"
done

# Upload M=5 only versions (day partition)
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}"
    echo "------------------------------------------------------------"
    echo "Uploading M5 ${scenario} scenario..."
    ssh "$USER@$SERVER" "mkdir -p $REMOTE_DIR"
    scp -r "${LOCAL_DIR}/PATE Retrospective Goodoverlap M5 ${scenario} GLM/"* "$USER@$SERVER:$REMOTE_DIR/"
    echo "Uploading population data for M5 ${scenario}..."
    scp "${LOCAL_DIR}/SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData" "$USER@$SERVER:$REMOTE_DIR/"
done

echo "============================================================"
echo "Submitting jobs to McCleary..."
echo "============================================================"

# Submit M=1,3,5 jobs to week partition
echo "------------------------------------------------------------"
echo "Submitting M=1,3,5 jobs to WEEK partition (7-day timeout)..."
echo "------------------------------------------------------------"
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m135_${scenario_lower}"
    echo "Submitting M135 ${scenario} scenario job to week partition..."
    JOB_ID=$(ssh "$USER@$SERVER" "cd $REMOTE_DIR && sbatch run_comparison_mccleary_optimized.sh" | awk '{print $4}')
    echo "  Job ID: $JOB_ID"
    # Store job IDs
    if [ "$scenario" == "CorCor" ]; then JOB_ID_M135_CORCOR=$JOB_ID; fi
    if [ "$scenario" == "MisCor" ]; then JOB_ID_M135_MISCOR=$JOB_ID; fi
    if [ "$scenario" == "CorMis" ]; then JOB_ID_M135_CORMIS=$JOB_ID; fi
    if [ "$scenario" == "MisMis" ]; then JOB_ID_M135_MISMIS=$JOB_ID; fi
done

# Submit M=5 only jobs to day partition
echo "------------------------------------------------------------"
echo "Submitting M=5 only jobs to DAY partition (22-hour timeout)..."
echo "------------------------------------------------------------"
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}"
    echo "Submitting M5 ${scenario} scenario job to day partition..."
    JOB_ID=$(ssh "$USER@$SERVER" "cd $REMOTE_DIR && sbatch run_comparison_mccleary_optimized.sh" | awk '{print $4}')
    echo "  Job ID: $JOB_ID"
    # Store job IDs
    if [ "$scenario" == "CorCor" ]; then JOB_ID_M5_CORCOR=$JOB_ID; fi
    if [ "$scenario" == "MisCor" ]; then JOB_ID_M5_MISCOR=$JOB_ID; fi
    if [ "$scenario" == "CorMis" ]; then JOB_ID_M5_CORMIS=$JOB_ID; fi
    if [ "$scenario" == "MisMis" ]; then JOB_ID_M5_MISMIS=$JOB_ID; fi
done

echo "============================================================"
echo "All 8 jobs submitted successfully!"
echo "============================================================"
echo ""
echo "Summary of submitted jobs:"
echo "  M=1,3,5 (week partition, 7-day timeout):"
echo "    CorCor: Job $JOB_ID_M135_CORCOR"
echo "    MisCor: Job $JOB_ID_M135_MISCOR"
echo "    CorMis: Job $JOB_ID_M135_CORMIS"
echo "    MisMis: Job $JOB_ID_M135_MISMIS"
echo ""
echo "  M=5 only (day partition, 22-hour timeout):"
echo "    CorCor: Job $JOB_ID_M5_CORCOR"
echo "    MisCor: Job $JOB_ID_M5_MISCOR"
echo "    CorMis: Job $JOB_ID_M5_CORMIS"
echo "    MisMis: Job $JOB_ID_M5_MISMIS"
echo ""
echo "To check status:"
echo "  ssh $USER@$SERVER 'squeue -u \$USER | grep pate'"
echo ""
echo "To check specific job:"
echo "  ssh $USER@$SERVER 'squeue -j <JOB_ID>'"
