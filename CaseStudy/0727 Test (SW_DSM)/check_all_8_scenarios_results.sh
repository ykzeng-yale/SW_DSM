#!/bin/bash

# Script to check results of all 8 scenario jobs from McCleary HPC

SERVER="login2.mccleary.ycrc.yale.edu"
USER="yz2324"
LOCAL_BASE_DIR="/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Code Experiment/0727 Test (SW_DSM)"

echo "============================================================"
echo "Checking status of all 8 jobs..."
echo "============================================================"

echo "Checking job queue status..."
ssh "$USER@$SERVER" "squeue -u $USER | grep -E 'JOBID|pate_m135|pate_m5'"

echo ""
echo "============================================================"
echo "Checking for output files and downloading results..."
echo "============================================================"

# Check and download M=1,3,5 results (week partition)
echo "------------------------------------------------------------"
echo "M=1,3,5 Results (week partition):"
echo "------------------------------------------------------------"
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m135_${scenario_lower}"
    LOCAL_DIR_SCENARIO="${LOCAL_BASE_DIR}/PATE Retrospective Goodoverlap M135 ${scenario} GLM"
    
    echo ""
    echo "Checking M135 ${scenario} results in $REMOTE_DIR"
    
    # Check for output files
    echo "  Output files:"
    ssh "$USER@$SERVER" "ls -lah $REMOTE_DIR/*.RData $REMOTE_DIR/*.csv 2>/dev/null | grep -v SuperPopGen | head -5"
    
    # Check for log files
    echo "  Log files:"
    ssh "$USER@$SERVER" "ls -lah $REMOTE_DIR/*.out $REMOTE_DIR/*.err 2>/dev/null | tail -2"
    
    # Download results if they exist
    echo "  Downloading results..."
    scp "$USER@$SERVER:$REMOTE_DIR/*.RData" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/*.csv" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/*.out" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/*.err" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
done

# Check and download M=5 only results (day partition)
echo ""
echo "------------------------------------------------------------"
echo "M=5 Only Results (day partition):"
echo "------------------------------------------------------------"
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}"
    LOCAL_DIR_SCENARIO="${LOCAL_BASE_DIR}/PATE Retrospective Goodoverlap M5 ${scenario} GLM"
    
    echo ""
    echo "Checking M5 ${scenario} results in $REMOTE_DIR"
    
    # Check for output files
    echo "  Output files:"
    ssh "$USER@$SERVER" "ls -lah $REMOTE_DIR/*.RData $REMOTE_DIR/*.csv 2>/dev/null | grep -v SuperPopGen | head -5"
    
    # Check for log files
    echo "  Log files:"
    ssh "$USER@$SERVER" "ls -lah $REMOTE_DIR/*.out $REMOTE_DIR/*.err 2>/dev/null | tail -2"
    
    # Download results if they exist
    echo "  Downloading results..."
    scp "$USER@$SERVER:$REMOTE_DIR/*.RData" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/*.csv" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/*.out" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
    scp "$USER@$SERVER:$REMOTE_DIR/*.err" "$LOCAL_DIR_SCENARIO/" 2>/dev/null
done

echo ""
echo "============================================================"
echo "Results check complete!"
echo "============================================================"

# Check for any errors in recent jobs
echo ""
echo "Checking for any recent errors in log files..."
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    echo ""
    echo "M135 ${scenario} last error (if any):"
    ssh "$USER@$SERVER" "tail -5 /gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m135_${scenario_lower}/*.err 2>/dev/null | grep -E 'error|Error|ERROR' | head -2"
    
    echo "M5 ${scenario} last error (if any):"
    ssh "$USER@$SERVER" "tail -5 /gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}/*.err 2>/dev/null | grep -E 'error|Error|ERROR' | head -2"
done
