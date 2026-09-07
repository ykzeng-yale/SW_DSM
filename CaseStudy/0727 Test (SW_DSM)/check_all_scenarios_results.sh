#!/bin/bash

# Check and download results for all 4 model specification scenarios
echo "============================================================"
echo "Checking Results for All Model Specification Scenarios"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"
BASE_DIR="/gpfs/gibbs/project/tong/yz2324"

# Array of scenarios
scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

# Check job status
echo "Checking job status..."
ssh $SERVER "squeue -u \$USER | grep 'pate_m135'"

echo ""
echo "============================================================"
echo "Checking output files for each scenario..."
echo "============================================================"

# Check output files for each scenario
for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="$BASE_DIR/pate_retrospective_goodoverlap_m135_${scenario_lower}"
    LOCAL_DIR="PATE Retrospective Goodoverlap M135 ${scenario} GLM"
    
    echo ""
    echo "------------------------------------------------------------"
    echo "$scenario Scenario:"
    echo "------------------------------------------------------------"
    
    echo "Output files:"
    ssh $SERVER "ls -lah $REMOTE_DIR/*.out $REMOTE_DIR/*.err 2>/dev/null | tail -5"
    
    echo ""
    echo "Result files:"
    ssh $SERVER "ls -lah $REMOTE_DIR/*.RData $REMOTE_DIR/*.csv 2>/dev/null | grep -v SuperPopGen | tail -5"
done

echo ""
echo "============================================================"
echo "Download results? (y/n)"
echo "============================================================"
read -p "Enter choice: " download_choice

if [ "$download_choice" = "y" ] || [ "$download_choice" = "Y" ]; then
    echo ""
    echo "Downloading results..."
    
    for scenario in "${scenarios[@]}"; do
        scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
        REMOTE_DIR="$BASE_DIR/pate_retrospective_goodoverlap_m135_${scenario_lower}"
        LOCAL_DIR="PATE Retrospective Goodoverlap M135 ${scenario} GLM"
        
        echo "------------------------------------------------------------"
        echo "Downloading $scenario results..."
        
        # Download result files
        rsync -avz --progress \
            $SERVER:$REMOTE_DIR/*.RData \
            $SERVER:$REMOTE_DIR/*.csv \
            $SERVER:$REMOTE_DIR/*.out \
            $SERVER:$REMOTE_DIR/*.err \
            "$LOCAL_DIR/" 2>/dev/null || echo "  No results to download yet"
    done
    
    echo ""
    echo "============================================================"
    echo "Download complete!"
    echo "============================================================"
else
    echo "Download skipped."
fi

echo ""
echo "To check latest progress for a specific scenario:"
for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    echo "  $scenario: ssh $SERVER 'tail -50 $BASE_DIR/pate_retrospective_goodoverlap_m135_${scenario_lower}/*.out'"
done
