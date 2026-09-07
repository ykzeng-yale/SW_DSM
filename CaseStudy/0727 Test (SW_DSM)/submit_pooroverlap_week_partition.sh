#!/bin/bash

echo "============================================================"
echo "Submitting Poor Overlap Jobs to WEEK Partition (7 days)"
echo "Full M=1,3,5 Analysis"
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
    echo "Updating and submitting $scenario scenario to week partition..."
    echo "============================================================"
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_m135_${scenario}_week"
    
    # Step 1: Create remote directory
    echo "Creating remote directory for $scenario (week)..."
    ssh $SERVER "mkdir -p $REMOTE_DIR"
    
    # Step 2: Create week partition submission script
    cat > "$LOCAL_DIR/run_comparison_mccleary_week.sh" << EOF
#!/bin/bash
#SBATCH --job-name=pate_poor_${scenario}_wk
#SBATCH --output=pate_retrospective_pooroverlap_${scenario}_week_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_${scenario}_week_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=30
#SBATCH --mem-per-cpu=8G
#SBATCH --time=7-00:00:00
#SBATCH --partition=week
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
echo "Scenario: $scenario (Week Partition, Full M=1,3,5)"
echo "============================================================"

# Load R module
module load R

# Run the R script
echo "Starting R script execution..."
Rscript compare_methods_pate_retrospective_mccleary.R

# Record end time
echo "============================================================"
echo "Job finished at: \$(date)"
echo "============================================================"
EOF
    
    # Step 3: Upload all files
    echo "Uploading files for $scenario to week partition directory..."
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
    
    # Step 4: Upload data file
    echo "Uploading data file..."
    rsync -avz "$LOCAL_DIR/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" $SERVER:$REMOTE_DIR/
    
    # Step 5: Submit job
    echo "Submitting $scenario to week partition..."
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_week.sh")
    job_id=$(echo $job_output | grep -o '[0-9]\+' | tail -1)
    job_ids="$job_ids $job_id"
    echo "Job submitted with ID: $job_id"
done

echo ""
echo "============================================================"
echo "All WEEK partition jobs submitted successfully!"
echo "============================================================"
echo "Job IDs: $job_ids"
echo ""
echo "Configuration:"
echo "  - Partition: week (7 days)"
echo "  - M values: 1, 3, 5 (full analysis)"
echo "  - CPUs: 30 cores"
echo "  - Memory: 240GB"
echo ""
echo "To check status:"
echo "ssh $SERVER 'squeue -u \$USER | grep wk'"
echo "============================================================"
