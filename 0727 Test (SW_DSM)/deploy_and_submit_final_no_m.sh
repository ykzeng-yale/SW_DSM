#!/bin/bash

echo "============================================================"
echo "Deploying FINAL scripts and submitting to tong account"
echo "NO M parameter, NO individual timeouts (matching Good Overlap)"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"

# Deploy scripts to all scenarios first
for scenario in CorCor MisCor CorMis MisMis; do
    echo ""
    echo "Deploying to $scenario..."
    
    # Define the target directory
    TARGET_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    
    # Copy the final script
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_FINAL_NO_M.R" \
       "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Update the scenario parameter
    sed -i '' "s/scenarios <- c(\"CorCor\")/scenarios <- c(\"$scenario\")/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Update output file names
    sed -i '' "s/_CorCor_FINAL/_${scenario}/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    # Update the description
    case $scenario in
        CorCor)
            DESC="CorCor (Both PS and PGS correct)"
            ;;
        MisCor)
            DESC="MisCor (PS misspecified, PGS correct)"
            ;;
        CorMis)
            DESC="CorMis (PS correct, PGS misspecified)"
            ;;
        MisMis)
            DESC="MisMis (Both PS and PGS misspecified)"
            ;;
    esac
    
    sed -i '' "s/Scenario: CorCor (Both PS and PGS correct)/Scenario: $DESC/g" \
        "$TARGET_DIR/compare_methods_pate_retrospective_mccleary_M5_100reps.R"
    
    echo "✓ Script deployed to $scenario"
done

echo ""
echo "============================================================"
echo "Now submitting all 4 scenarios to tong account..."
echo "============================================================"

# Track job IDs
job_ids=""

for scenario in CorCor MisCor CorMis MisMis; do
    echo ""
    echo "============================================================"
    echo "Submitting $scenario scenario (M=5, 100 reps) to tong account..."
    echo "============================================================"
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 $scenario GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_${scenario}_100reps_FINAL"
    
    # Step 1: Create remote directory
    echo "Creating remote directory..."
    ssh $SERVER "mkdir -p $REMOTE_DIR"
    
    # Step 2: Create SLURM script
    cat > "$LOCAL_DIR/run_comparison_mccleary_M5_100reps_final.sh" << EOF
#!/bin/bash
#SBATCH --job-name=FINAL_${scenario}
#SBATCH --output=pate_retrospective_pooroverlap_${scenario}_M5_100reps_final_%j.out
#SBATCH --error=pate_retrospective_pooroverlap_${scenario}_M5_100reps_final_%j.err
#SBATCH --account=tong
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --mail-type=ALL
#SBATCH --mail-user=yukang.zhang@yale.edu

# Set working directory
cd $REMOTE_DIR

# Record start time
echo "============================================================"
echo "FINAL VERSION - Job started at: \$(date)"
echo "Job ID: \$SLURM_JOB_ID"
echo "Account: tong"
echo "Node: \$HOSTNAME"
echo "Working directory: \$(pwd)"
echo "Scenario: $scenario (Day Partition, M=5, 100 Reps - FINAL)"
echo "Cores: 20, Memory: 160GB total"
echo "============================================================"
echo ""
echo "Key fixes applied:"
echo "1. ✅ REMOVED M parameter from all dsmatchATE calls"
echo "2. ✅ NO individual timeouts (job has 23 hour limit)"
echo "3. ✅ Source dsmatch files INSIDE worker"
echo "4. ✅ DSM: X_ps for X, X_pg for lp.pg"
echo "5. ✅ PG: model.pg='glm'"
echo "6. ✅ Matching Good Overlap CORRECTED exactly"
echo ""
echo "Expected Results (CorCor):"
echo "- DSM: ~1-2% bias, ~94-96% coverage"
echo "- PG: ~2-3% bias, ~93-95% coverage"
echo "- PS: ~2-3% bias, ~93-95% coverage"
echo "- PS Weighted: ~1-2% bias, ~94-96% coverage"
echo "- WDSM: <1% bias, ~95% coverage"
echo "============================================================"

# Load R module
module load R

# Run the R script
echo "Starting R script execution (M=5, 100 reps)..."
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
    
    # Upload all supporting files
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
      --exclude="*_FIXED*.R" \
      --exclude="*_CORRECT*.R" \
      --exclude="*_CORRECTED*.R" \
      --exclude="*_FINAL_NO_M.R" \
      --exclude="compare_methods_pate_retrospective_mccleary.R" \
      --exclude="compare_methods_pate_retrospective_mccleary_M5.R" \
      "$LOCAL_DIR/" $SERVER:$REMOTE_DIR/
    
    # Step 4: Upload data file
    echo "Uploading data file..."
    rsync -avz "$LOCAL_DIR/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" $SERVER:$REMOTE_DIR/
    
    # Step 5: Submit job
    echo "Submitting $scenario job to tong account..."
    job_output=$(ssh $SERVER "cd $REMOTE_DIR && sbatch run_comparison_mccleary_M5_100reps_final.sh")
    job_id=$(echo $job_output | grep -o '[0-9]\+' | tail -1)
    job_ids="$job_ids $job_id"
    echo "Job submitted with ID: $job_id"
done

echo ""
echo "============================================================"
echo "All FINAL jobs submitted to tong account successfully!"
echo "============================================================"
echo "Job IDs: $job_ids"
echo ""
echo "Configuration:"
echo "  - Account: tong"
echo "  - Partition: day (23 hours)"
echo "  - M values: 1:1 (dsmatchATE default)"
echo "  - Replications: 100"
echo "  - Cores: 20"
echo "  - Memory: 8GB per CPU (160GB total)"
echo ""
echo "FINAL Implementation (matching Good Overlap CORRECTED):"
echo "  ✅ NO M parameter in dsmatchATE calls"
echo "  ✅ NO individual timeouts"
echo "  ✅ Source dsmatch files inside worker"
echo "  ✅ DSM: X_ps for PS, X_pg for PG"
echo "  ✅ PG: model.pg='glm'"
echo "  ✅ All methods should produce results"
echo ""
echo "To check status:"
echo "ssh $SERVER 'squeue -u \$USER --account=tong | grep FINAL'"
echo ""
echo "To check results when complete:"
echo "ssh $SERVER 'ls -la /gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_*_100reps_FINAL/*.csv'"
echo "============================================================"
