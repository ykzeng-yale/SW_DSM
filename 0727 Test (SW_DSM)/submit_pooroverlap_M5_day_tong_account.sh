#!/bin/bash

echo "============================================================"
echo "Submitting Poor Overlap M=5 Jobs to DAY Partition"
echo "Using TONG Account (not li_fan)"
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
    echo "Preparing and submitting $scenario scenario (M=5 only) to day partition (tong account)..."
    echo "============================================================"
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_day_tong"
    
    # Step 1: Create remote directory
    echo "Creating remote directory for $scenario (M=5 day, tong account)..."
    ssh $SERVER "mkdir -p $REMOTE_DIR"
    
    # Step 2: Create M=5-only version of the R script if not already created
    echo "Creating M=5-only version of comparison script..."
    if [ ! -f "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5.R" ]; then
        sed 's/M_values <- c(1, 3, 5)/M_values <- c(5)/g' \
            "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary.R" > \
            "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5.R"
        
        # Also update output file names in the M5 version
        sed -i '' 's/comparison_table_/comparison_table_M5_/g' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5.R"
        sed -i '' 's/comparison_results_/comparison_results_M5_/g' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5.R"
    fi
    
    # Step 3: Create day partition submission script for M=5 with TONG account
    cat > "$LOCAL_DIR/run_comparison_mccleary_M5_day_tong.sh" << EOF
#!/bin/bash
#SBATCH --job-name=pate_poor_${scenario}_M5_tong
#SBATCH --output=pate_retrospective_pooroverlap_${scenario}_M5_tong_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_${scenario}_M5_tong_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=30
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --account=tong
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd $REMOTE_DIR

# Record start time
echo "============================================================"
echo "Job started at: \$(date)"
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$HOSTNAME"
echo "Working directory: \$(pwd)"
echo "Scenario: $scenario (Day Partition, M=5 Only)"
echo "Account: tong"
echo "============================================================"

# Load R module
module load R

# Run the R script (M=5 version)
echo "Starting R script execution (M=5 only, tong account)..."
Rscript compare_methods_pate_retrospective_mccleary_M5.R

# Record end time
echo "============================================================"
echo "Job finished at: \$(date)"
echo "============================================================"
EOF
    
    # Step 4: Upload all files
    echo "Uploading files for $scenario (M=5, tong account) to day partition directory..."
    rsync -avz --progress \
      --exclude="*.RData" \
      --exclude="*.pdf" \
      --exclude="*.csv" \
      --exclude="*.txt" \
      --exclude="*.md" \
      --exclude="*.log" \
      --exclude="*.out" \
      --exclude="*.err" \
      --exclude="compare_methods_pate_retrospective_mccleary.R" \
      "$LOCAL_DIR/" $SERVER:$REMOTE_DIR/
    
    # Upload the M5 version of the comparison script
    rsync -avz "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5.R" $SERVER:$REMOTE_DIR/
    rsync -avz "$LOCAL_DIR/run_comparison_mccleary_M5_day_tong.sh" $SERVER:$REMOTE_DIR/
    
    # Step 5: Upload data file
    echo "Uploading data file..."
    rsync -avz "$LOCAL_DIR/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" $SERVER:$REMOTE_DIR/
    
    # Step 6: Submit job
    echo "Submitting $scenario (M=5) to day partition with tong account..."
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_M5_day_tong.sh")
    job_id=$(echo $job_output | grep -o '[0-9]\+' | tail -1)
    job_ids="$job_ids $job_id"
    echo "Job submitted with ID: $job_id"
done

echo ""
echo "============================================================"
echo "All DAY partition jobs (M=5 only) submitted with TONG account!"
echo "============================================================"
echo "Job IDs: $job_ids"
echo ""
echo "Configuration:"
echo "  - Account: tong (not li_fan)"
echo "  - Partition: day (22 hours)"
echo "  - M values: 5 only (reduced analysis)"
echo "  - CPUs: 30 cores"
echo "  - Memory: 240GB"
echo ""
echo "To check status:"
echo "ssh $SERVER 'squeue -u \$USER | grep tong'"
echo ""
echo "Note: These jobs are running under the 'tong' account,"
echo "separate from the 'li_fan' account jobs."
echo "============================================================"

