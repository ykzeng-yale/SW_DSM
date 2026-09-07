#!/bin/bash

echo "============================================================"
echo "Complete Setup and Submission for M=5 100-Rep Jobs"
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
    echo "Setting up $scenario scenario (M=5, 100 reps)"
    echo "============================================================"
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_100reps_lifan"
    
    # Step 1: Create the updated comparison script locally
    echo "Creating updated comparison script for $scenario..."
    
    # Read the original script and modify key parameters
    cat "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary.R" | \
    sed 's/n_reps <- 1000/n_reps <- 100/' | \
    sed 's/M_values <- c(1, 3, 5)/M_values <- c(5)/' | \
    sed 's/n_cores <- 30/n_cores <- 20/' | \
    sed 's/batch_size <- 100/batch_size <- 20/' | \
    sed "s/scenarios <- c(\"CorCor\", \"MisCor\", \"CorMis\", \"MisMis\")/scenarios <- c(\"$scenario\")/" | \
    sed 's/comparison_table_/comparison_table_M5_100reps_/' | \
    sed 's/comparison_results_/comparison_results_M5_100reps_/' | \
    sed 's/parallel_log\.txt/parallel_log_100reps.txt/' \
    > "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Step 2: Create the SLURM script locally
    echo "Creating SLURM script for $scenario..."
    cat > "$LOCAL_DIR/run_comparison_mccleary_M5_100reps_lifan.sh" << EOF
#!/bin/bash
#SBATCH --job-name=pate_${scenario}_M5_100r
#SBATCH --output=pate_retrospective_pooroverlap_${scenario}_M5_100reps_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_${scenario}_M5_100reps_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=22:00:00
#SBATCH --partition=day
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
echo "Scenario: $scenario (Day Partition, M=5, 100 Reps)"
echo "Cores: 20, Memory: 160GB total"
echo "Batch size: 20 replications per batch"
echo "============================================================"

# Load R module
module load R

# Run the R script (M=5, 100 reps version)
echo "Starting R script execution (M=5, 100 reps)..."
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps.R

# Record end time
echo "============================================================"
echo "Job finished at: \$(date)"
echo "============================================================"
EOF
    
    # Step 3: Create remote directory
    echo "Creating remote directory..."
    ssh $SERVER "mkdir -p $REMOTE_DIR"
    
    # Step 4: Upload all necessary files
    echo "Uploading R script and SLURM script..."
    
    # Upload the comparison script
    rsync -avz "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R" $SERVER:$REMOTE_DIR/
    
    # Upload the SLURM script
    rsync -avz "$LOCAL_DIR/run_comparison_mccleary_M5_100reps_lifan.sh" $SERVER:$REMOTE_DIR/
    
    # Upload all other necessary files (excluding large data files we'll handle separately)
    echo "Uploading supporting files..."
    rsync -avz --progress \
      --include="*.R" \
      --include="dsmatch-master/" \
      --include="dsmatch-master/**" \
      --exclude="*.RData" \
      --exclude="*.pdf" \
      --exclude="*.csv" \
      --exclude="*.txt" \
      --exclude="*.md" \
      --exclude="*.log" \
      --exclude="*.out" \
      --exclude="*.err" \
      --exclude="compare_methods_pate_retrospective_mccleary.R" \
      --exclude="compare_methods_pate_retrospective_mccleary_M5.R" \
      "$LOCAL_DIR/" $SERVER:$REMOTE_DIR/
    
    # Step 5: Upload data file
    echo "Uploading data file..."
    rsync -avz "$LOCAL_DIR/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" $SERVER:$REMOTE_DIR/
    
    # Step 6: Submit job
    echo "Submitting $scenario (M=5, 100 reps) to day partition..."
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_M5_100reps_lifan.sh")
    job_id=$(echo $job_output | grep -o '[0-9]\+' | tail -1)
    job_ids="$job_ids $job_id"
    echo "Job submitted with ID: $job_id"
done

echo ""
echo "============================================================"
echo "All M=5 100-rep jobs submitted successfully!"
echo "============================================================"
echo "Job IDs: $job_ids"
echo ""
echo "Configuration Summary:"
echo "  - Account: li_fan (default)"
echo "  - Partition: day (22 hours)"
echo "  - M values: 5 only"
echo "  - Replications: 100 (reduced from 1000)"
echo "  - Cores: 20"
echo "  - Memory: 8GB per CPU (160GB total)"
echo "  - Batch size: 20 replications per batch"
echo ""
echo "To check status:"
echo "ssh $SERVER 'squeue -u \$USER | grep M5_100r'"
echo ""
echo "Expected runtime: ~2-4 hours (much faster than 1000 reps)"
echo "============================================================"
