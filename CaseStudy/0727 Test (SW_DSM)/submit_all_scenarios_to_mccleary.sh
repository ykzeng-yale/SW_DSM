#!/bin/bash

# Master submission script for all 4 model specification scenarios
echo "============================================================"
echo "Submitting PATE Retrospective Model Misspecification Scenarios"
echo "Scenarios: CorCor, MisCor, CorMis, MisMis (as separate jobs)"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"
BASE_DIR="/gpfs/gibbs/project/tong/yz2324"

# Array of scenarios
scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

# Create remote directories for all scenarios
echo "Creating remote directories..."
for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    ssh $SERVER "mkdir -p $BASE_DIR/pate_retrospective_goodoverlap_m135_${scenario_lower}"
done

echo ""
echo "Uploading files for all scenarios..."

# Upload files for each scenario
for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    LOCAL_DIR="PATE Retrospective Goodoverlap M135 ${scenario} GLM"
    REMOTE_DIR="$BASE_DIR/pate_retrospective_goodoverlap_m135_${scenario_lower}"
    
    echo "------------------------------------------------------------"
    echo "Uploading $scenario scenario..."
    
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
    
    # Upload the population data file
    echo "Uploading population data for $scenario..."
    scp "PATE Retrospective Goodoverlap M135 ${scenario} GLM/SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData" \
        $SERVER:$REMOTE_DIR/ 2>/dev/null || echo "  (Population data already exists or not found locally)"
done

echo ""
echo "============================================================"
echo "Submitting jobs to McCleary..."
echo "============================================================"

# Submit jobs for each scenario
declare -a job_ids

for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="$BASE_DIR/pate_retrospective_goodoverlap_m135_${scenario_lower}"
    
    echo "Submitting $scenario scenario job..."
    
    # Submit job and capture job ID
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_optimized.sh")
    job_id=$(echo $job_output | grep -oE '[0-9]+$')
    
    if [ -n "$job_id" ]; then
        job_ids+=("$job_id")
        echo "  Job ID: $job_id"
    else
        echo "  Failed to submit $scenario job"
    fi
    
    # Brief pause between submissions
    sleep 2
done

echo ""
echo "============================================================"
echo "All jobs submitted successfully!"
echo "============================================================"
echo ""
echo "Job IDs:"
for i in "${!scenarios[@]}"; do
    if [ -n "${job_ids[$i]}" ]; then
        echo "  ${scenarios[$i]}: ${job_ids[$i]}"
    fi
done

echo ""
echo "To check status of all jobs:"
echo "  ssh $SERVER 'squeue -u \$USER'"
echo ""
echo "To check specific scenario output:"
for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    echo "  $scenario: ssh $SERVER 'ls -la $BASE_DIR/pate_retrospective_goodoverlap_m135_${scenario_lower}/*.out'"
done
echo ""
echo "============================================================"
