#!/bin/bash

# Script to submit M=5 only scenario jobs to McCleary HPC using "tong" account
# 4 reduced (M=5 only) to day partition with 22-hour timeout

SERVER="login2.mccleary.ycrc.yale.edu"
USER="yz2324"
LOCAL_DIR="/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Code Experiment/0727 Test (SW_DSM)"

echo "============================================================"
echo "Preparing M=5 jobs for 'tong' account submission..."
echo "============================================================"

# First, update the submission scripts to use tong account
for scenario in CorCor MisCor CorMis MisMis; do
    LOCAL_DIR_SCENARIO="${LOCAL_DIR}/PATE Retrospective Goodoverlap M5 ${scenario} GLM"
    echo "Updating submission script for M5 ${scenario} to use tong account..."
    
    # Create a new submission script with tong account
    cat > "${LOCAL_DIR_SCENARIO}/run_comparison_mccleary_tong.sh" << 'EOF'
#!/bin/bash
#SBATCH --job-name=pate_m5_SCENARIO_tong
#SBATCH --output=pate_m5_SCENARIO_tong_%j.out
#SBATCH --error=pate_m5_SCENARIO_tong_%j.err
#SBATCH --cpus-per-task=30
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --account=tong

# Load required modules
module load R/4.3.2-foss-2022b

# Set up environment
export OMP_NUM_THREADS=1
export R_LIBS_USER=/gpfs/gibbs/project/tong/yz2324/R_libs

# Run the R script
echo "Starting PATE Retrospective M5 SCENARIO comparison at $(date)"
echo "Running on node: $(hostname)"
echo "Using account: tong"
echo "Number of CPUs: ${SLURM_CPUS_PER_TASK}"
echo "Memory per CPU: 8G"

Rscript compare_methods_pate_retrospective_mccleary.R

echo "Completed at $(date)"
EOF
    
    # Replace SCENARIO placeholder with actual scenario
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    sed -i '' "s/SCENARIO/${scenario_lower}/g" "${LOCAL_DIR_SCENARIO}/run_comparison_mccleary_tong.sh"
done

echo "============================================================"
echo "Uploading M=5 scenarios with tong account scripts..."
echo "============================================================"

# Upload M=5 only versions with new submission scripts
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_tong"
    echo "------------------------------------------------------------"
    echo "Uploading M5 ${scenario} scenario for tong account..."
    ssh "$USER@$SERVER" "mkdir -p $REMOTE_DIR"
    scp -r "${LOCAL_DIR}/PATE Retrospective Goodoverlap M5 ${scenario} GLM/"* "$USER@$SERVER:$REMOTE_DIR/"
    echo "Uploading population data for M5 ${scenario}..."
    scp "${LOCAL_DIR}/SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData" "$USER@$SERVER:$REMOTE_DIR/"
done

echo "============================================================"
echo "Submitting M=5 jobs to McCleary using 'tong' account..."
echo "============================================================"

# Submit M=5 only jobs to day partition with tong account
echo "------------------------------------------------------------"
echo "Submitting M=5 only jobs to DAY partition with 'tong' account..."
echo "------------------------------------------------------------"
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_tong"
    echo "Submitting M5 ${scenario} scenario job with tong account..."
    JOB_ID=$(ssh "$USER@$SERVER" "cd $REMOTE_DIR && sbatch run_comparison_mccleary_tong.sh" | awk '{print $4}')
    echo "  Job ID: $JOB_ID (account: tong)"
    # Store job IDs
    if [ "$scenario" == "CorCor" ]; then JOB_ID_M5_CORCOR_TONG=$JOB_ID; fi
    if [ "$scenario" == "MisCor" ]; then JOB_ID_M5_MISCOR_TONG=$JOB_ID; fi
    if [ "$scenario" == "CorMis" ]; then JOB_ID_M5_CORMIS_TONG=$JOB_ID; fi
    if [ "$scenario" == "MisMis" ]; then JOB_ID_M5_MISMIS_TONG=$JOB_ID; fi
done

echo "============================================================"
echo "M=5 jobs submitted successfully with 'tong' account!"
echo "============================================================"
echo ""
echo "Summary of submitted jobs (tong account):"
echo "  M=5 only (day partition, 22-hour timeout, account: tong):"
echo "    CorCor: Job $JOB_ID_M5_CORCOR_TONG"
echo "    MisCor: Job $JOB_ID_M5_MISCOR_TONG"
echo "    CorMis: Job $JOB_ID_M5_CORMIS_TONG"
echo "    MisMis: Job $JOB_ID_M5_MISMIS_TONG"
echo ""
echo "To check status of tong account jobs:"
echo "  ssh $USER@$SERVER 'squeue -A tong -u \$USER'"
echo ""
echo "To check all jobs (both accounts):"
echo "  ssh $USER@$SERVER 'squeue -u \$USER'"
