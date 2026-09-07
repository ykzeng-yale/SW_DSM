#!/bin/bash

# Script to check results of M=5 scenario jobs from 'tong' account

SERVER="login2.mccleary.ycrc.yale.edu"
USER="yz2324"
LOCAL_BASE_DIR="/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Code Experiment/0727 Test (SW_DSM)"

echo "============================================================"
echo "Checking status of M=5 jobs on 'tong' account..."
echo "============================================================"

echo "Checking job queue status for tong account..."
ssh "$USER@$SERVER" "squeue -A tong -u $USER | grep -E 'JOBID|pate_m5'"

echo ""
echo "============================================================"
echo "Checking for output files and downloading results..."
echo "============================================================"

# Check and download M=5 results from tong account directories
echo "------------------------------------------------------------"
echo "M=5 Only Results (day partition, tong account):"
echo "------------------------------------------------------------"
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_tong"
    LOCAL_DIR_SCENARIO="${LOCAL_BASE_DIR}/PATE Retrospective Goodoverlap M5 ${scenario} GLM Tong"
    
    echo ""
    echo "Checking M5 ${scenario} results (tong account) in $REMOTE_DIR"
    
    # Create local directory for tong results if it doesn't exist
    mkdir -p "$LOCAL_DIR_SCENARIO"
    
    # Check for output files
    echo "  Output files:"
    ssh "$USER@$SERVER" "ls -lah $REMOTE_DIR/*.RData $REMOTE_DIR/*.csv 2>/dev/null | grep -v SuperPopGen | head -5"
    
    # Check for log files
    echo "  Log files:"
    ssh "$USER@$SERVER" "ls -lah $REMOTE_DIR/*.out $REMOTE_DIR/*.err 2>/dev/null | tail -2"
    
    # Download results if they exist
    echo "  Downloading results to ${LOCAL_DIR_SCENARIO}..."
    scp "$USER@$SERVER:$REMOTE_DIR/*.RData" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/*.csv" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/*.out" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/*.err" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
done

echo ""
echo "============================================================"
echo "Results check complete for tong account jobs!"
echo "============================================================"

# Check for any errors in recent jobs
echo ""
echo "Checking for any recent errors in tong account log files..."
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    echo ""
    echo "M5 ${scenario} (tong) last error (if any):"
    ssh "$USER@$SERVER" "tail -5 /gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_tong/*.err 2>/dev/null | grep -E 'error|Error|ERROR' | head -2"
done

echo ""
echo "============================================================"
echo "Status Summary"
echo "============================================================"
echo "Jobs with 'tong' account are saved to: *_tong directories"
echo "Jobs with 'li_fan' account remain in original directories"
