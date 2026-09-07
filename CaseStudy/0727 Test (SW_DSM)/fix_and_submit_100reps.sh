#!/bin/bash

echo "============================================================"
echo "Fixing and Submitting Poor Overlap M=5 Jobs (100 Reps)"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"

# Scenarios to submit
scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

# Track job IDs
job_ids=""

for scenario in "${scenarios[@]}"; do
    echo ""
    echo "Fixing and submitting $scenario scenario (M=5, 100 reps)..."
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_100reps_lifan"
    
    # Upload the missing SLURM script
    echo "Uploading missing SLURM script for $scenario..."
    ssh $SERVER "cat > $REMOTE_DIR/run_comparison_mccleary_M5_100reps_lifan.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=pate_poor_${scenario}_M5_100r
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
echo \"============================================================\"
echo \"Job started at: \\\$(date)\"
echo \"Job ID: \\\$SLURM_JOB_ID\"
echo \"Node: \\\$HOSTNAME\"
echo \"Working directory: \\\$(pwd)\"
echo \"Scenario: $scenario (Day Partition, M=5, 100 Reps)\"
echo \"Cores: 20, Memory: 160GB total\"
echo \"============================================================\"

# Load R module
module load R

# Run the R script (M=5, 100 reps version)
echo \"Starting R script execution (M=5, 100 reps)...\"
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps.R

# Record end time
echo \"============================================================\"
echo \"Job finished at: \\\$(date)\"
echo \"============================================================\"
EOF"
    
    # Make it executable
    ssh $SERVER "chmod +x $REMOTE_DIR/run_comparison_mccleary_M5_100reps_lifan.sh"
    
    # Submit job
    echo "Submitting $scenario (M=5, 100 reps) to day partition with li_fan account..."
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_M5_100reps_lifan.sh")
    job_id=$(echo $job_output | grep -o '[0-9]\+' | tail -1)
    job_ids="$job_ids $job_id"
    echo "Job submitted with ID: $job_id"
done

echo ""
echo "============================================================"
echo "All jobs fixed and submitted!"
echo "============================================================"
echo "Job IDs: $job_ids"
echo ""
echo "To check status:"
echo "ssh $SERVER 'squeue -u \$USER | grep M5_100r'"
echo "============================================================"
