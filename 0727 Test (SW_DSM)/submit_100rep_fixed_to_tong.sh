#!/bin/bash

echo "==============================================================="
echo "Submitting 100-Replication Version of ALL-FIXED Scripts"
echo "==============================================================="
echo ""
echo "Based on successful 20-rep run with all fixes:"
echo "✅ Sample size: n=5000"
echo "✅ Function names: compute_wdsm_method2_ci_FIXED"
echo "✅ dsmatchATE fields: est.ds, est.pg, est.ps"
echo "✅ All 5 methods working"
echo ""

# Use new timestamp for this submission
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_BASE="/gpfs/gibbs/project/tong/yz2324/pooroverlap_100rep_${TIMESTAMP}"

echo "Creating new remote directory: $REMOTE_BASE"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_BASE"

# Submit each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "=========================================="
    echo "Processing $scenario scenario (100 reps)..."
    echo "=========================================="
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_DIR="$REMOTE_BASE/${scenario}"
    
    # Create remote directory
    echo "Creating remote directory..."
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"
    
    # Create modified R script with 100 replications
    cp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R" \
       "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps.R"
    
    # Update to 100 replications
    sed -i '' 's/n_reps <- 20/n_reps <- 100/' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps.R"
    sed -i '' 's/20 replicates/100 replicates/g' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps.R"
    sed -i '' 's/20reps/100reps/g' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps.R"
    sed -i '' 's/TEST RUN with 20/PRODUCTION RUN with 100/' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps.R"
    
    # Upload all necessary files
    echo "Uploading files..."
    
    # Upload 100-rep comparison script
    scp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Upload WDSM functions
    scp "$LOCAL_DIR/wdsm_method2_multinomial_bootstrap.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    scp "$LOCAL_DIR/wdsm_ci_functions.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Upload dsmatch-master
    echo "Uploading dsmatch-master..."
    scp -r dsmatch-master \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Upload data
    scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Create SLURM script with longer time limit for 100 reps
    cat > temp_slurm_${scenario}_100rep.sh << EOF
#!/bin/bash
#SBATCH --job-name=100rep_${scenario}
#SBATCH --output=${scenario}_100rep_%j.out
#SBATCH --error=${scenario}_100rep_%j.err
#SBATCH --time=12:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

cd $REMOTE_DIR

# Load R module
module load R

echo "=========================================="
echo "Starting 100-REP ${scenario} Production Run"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"
echo ""
echo "Configuration:"
echo "- Sample size: n=5000"
echo "- Scenario: ${scenario}"
echo "- Replicates: 100 (PRODUCTION)"
echo "- Bootstrap: 200"
echo "- M: 5"
echo "- All 5 methods enabled"
echo ""

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_100reps.R

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Upload SLURM script
    scp temp_slurm_${scenario}_100rep.sh \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/run_job.sh"
    
    # Submit the job
    echo "Submitting job for $scenario (100 reps)..."
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu \
             "cd $REMOTE_DIR && sbatch run_job.sh" | awk '{print $4}')
    
    echo "✅ Submitted Job ID: $JOB_ID for $scenario (100 reps)"
    
    # Clean up local temp files
    rm -f temp_slurm_${scenario}_100rep.sh
    rm -f "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_100reps.R"
done

echo ""
echo "==============================================================="
echo "All 100-REPLICATION jobs submitted!"
echo "==============================================================="
echo ""
echo "Remote directory: $REMOTE_BASE"
echo ""
echo "Configuration:"
echo "✅ Replications: 100 (5x more than test run)"
echo "✅ Time limit: 12 hours (day partition)"
echo "✅ All 5 methods enabled"
echo "✅ All fixes from successful 20-rep run applied"
echo ""
echo "Expected runtime: 1-2 hours per scenario (based on 20-rep taking ~17-19 min)"
echo ""
echo "To check status:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep 100rep'"
echo ""
echo "To monitor progress:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'for s in CorCor MisCor CorMis MisMis; do echo \"\$s:\"; tail -5 $REMOTE_BASE/\${s}/*.out 2>/dev/null | grep -E \"replicate|Completed\"; done'"
echo ""
echo "To download results when complete:"
echo "for s in CorCor MisCor CorMis MisMis; do"
echo "  scp yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_BASE/\${s}/raw_results_100reps_\${s}_FIXED_V3.RData pooroverlap_100rep_\${s}.RData"
echo "  echo \"Downloaded \${s}\""
echo "done"
