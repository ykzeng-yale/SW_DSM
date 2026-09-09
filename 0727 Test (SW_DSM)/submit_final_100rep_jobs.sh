#!/bin/bash

echo "============================================================"
echo "Submitting FINAL 100-rep jobs to li_fan account (day partition)"
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
    echo "Submitting FINAL $scenario scenario (M=5, 100 reps)..."
    echo "============================================================"
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_100reps_FINAL"
    
    # Step 1: Create remote directory
    echo "Creating remote directory..."
    ssh $SERVER "mkdir -p $REMOTE_DIR"
    
    # Step 2: Create SLURM script
    cat > "$LOCAL_DIR/run_comparison_mccleary_M5_100reps_final.sh" << EOF
#!/bin/bash
#SBATCH --job-name=FINAL_${scenario}_100
#SBATCH --output=pate_retrospective_pooroverlap_${scenario}_M5_100reps_final_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_${scenario}_M5_100reps_final_%j.err
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
echo "FINAL VERSION - Job started at: \$(date)"
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$HOSTNAME"
echo "Working directory: \$(pwd)"
echo "Scenario: $scenario (Day Partition, M=5, 100 Reps - FINAL)"
echo "Cores: 20, Memory: 160GB total"
echo "============================================================"
echo ""
echo "Implementation Details:"
echo "1. DSM: X for PS model, model.pg='linpred' with lp.pg for PG model"
echo "2. PS/PG matching: Only covariate changes via interaction term"
echo "3. Truly independent PS and PG specifications"
echo ""
echo "Expected Results (CorCor):"
echo "- WDSM: <1% bias, ~95% coverage"
echo "- DSM: ~1-2% bias, ~94-96% coverage"
echo "============================================================"

# Load R module
module load R

# Run the final R script
echo "Starting FINAL R script execution (M=5, 100 reps)..."
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps.R

# Record end time
echo "============================================================"
echo "Job finished at: \$(date)"
echo "============================================================"
EOF
    
    # Step 3: Upload all necessary files
    echo "Uploading files to $REMOTE_DIR..."
    
    # Upload the comparison script
    rsync -avz "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R" $SERVER:$REMOTE_DIR/
    
    # Upload the SLURM script
    rsync -avz "$LOCAL_DIR/run_comparison_mccleary_M5_100reps_final.sh" $SERVER:$REMOTE_DIR/
    
    # Upload all supporting files (R scripts, etc.)
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
      --exclude="*_FIXED.R" \
      --exclude="*_CORRECT.R" \
      --exclude="*_FINAL.R" \
      --exclude="compare_methods_pate_retrospective_mccleary.R" \
      --exclude="compare_methods_pate_retrospective_mccleary_M5.R" \
      "$LOCAL_DIR/" $SERVER:$REMOTE_DIR/
    
    # Step 4: Upload data file
    echo "Uploading data file..."
    rsync -avz "$LOCAL_DIR/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" $SERVER:$REMOTE_DIR/
    
    # Step 5: Submit job
    echo "Submitting FINAL $scenario job..."
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_M5_100reps_final.sh")
    job_id=$(echo $job_output | grep -o '[0-9]\+' | tail -1)
    job_ids="$job_ids $job_id"
    echo "Job submitted with ID: $job_id"
done

echo ""
echo "============================================================"
echo "All FINAL 100-rep jobs submitted successfully!"
echo "============================================================"
echo "Job IDs: $job_ids"
echo ""
echo "Configuration:"
echo "  - Account: li_fan (default)"
echo "  - Partition: day (22 hours)"
echo "  - M values: 5 only"
echo "  - Replications: 100"
echo "  - Cores: 20"
echo "  - Memory: 8GB per CPU (160GB total)"
echo ""
echo "Final Implementation:"
echo "  - DSM: X = X_ps_dsm, model.pg = 'linpred', lp.pg = X_pg_dsm"
echo "  - Allows truly independent PS and PG specifications"
echo "  - Each scenario correctly handles interaction terms"
echo ""
echo "To check status:"
echo "ssh $SERVER 'squeue -u \$USER | grep FINAL'"
echo ""
echo "To check results when complete:"
echo "ssh $SERVER 'ls -la /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_100reps_FINAL/*.csv'"
echo "============================================================"
