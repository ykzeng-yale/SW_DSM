#!/bin/bash

echo "==============================================================="
echo "Submitting 1000-Replication Version of ALL-FIXED Scripts"
echo "==============================================================="
echo ""
echo "Based on successful 100-rep run with all fixes:"
echo "✅ Sample size: n=5000"
echo "✅ Function names: compute_wdsm_method2_ci_FIXED"
echo "✅ dsmatchATE fields: est.ds, est.pg, est.ps"
echo "✅ All 5 methods working"
echo "✅ Account: li_fan (changed from tong)"
echo ""

# Use new timestamp for this submission
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_BASE="/gpfs/gibbs/project/li_fan/yz2324/pooroverlap_1000rep_${TIMESTAMP}"

echo "Creating new remote directory: $REMOTE_BASE"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_BASE"

# Submit each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "=========================================="
    echo "Processing $scenario scenario (1000 reps)..."
    echo "=========================================="
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_DIR="$REMOTE_BASE/${scenario}"
    
    # Create remote directory
    echo "Creating remote directory..."
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"
    
    # Create modified R script with 1000 replications (only change from 100 to 1000)
    cp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R" \
       "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_1000reps.R"
    
    # Update to 1000 replications (minimal changes for consistency)
    sed -i '' 's/n_reps <- 20/n_reps <- 1000/' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_1000reps.R"
    sed -i '' 's/20 replicates/1000 replicates/g' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_1000reps.R"
    sed -i '' 's/20reps/1000reps/g' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_1000reps.R"
    sed -i '' 's/TEST RUN with 20/PRODUCTION RUN with 1000/' "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_1000reps.R"
    
    # Upload all necessary files
    echo "Uploading files..."
    
    # Upload 1000-rep comparison script
    scp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_1000reps.R" \
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
    
    # Create SLURM script with 23-hour time limit for 1000 reps
    cat > temp_slurm_${scenario}_1000rep.sh << EOF
#!/bin/bash
#SBATCH --job-name=1000rep_${scenario}
#SBATCH --output=${scenario}_1000rep_%j.out
#SBATCH --error=${scenario}_1000rep_%j.err
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --account=li_fan

cd $REMOTE_DIR

# Load R module
module load R

echo "=========================================="
echo "Starting 1000-REP ${scenario} Production Run"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"
echo ""
echo "Configuration:"
echo "- Sample size: n=5000"
echo "- Scenario: ${scenario}"
echo "- Replicates: 1000 (FULL PRODUCTION)"
echo "- Bootstrap: 200"
echo "- M: 5"
echo "- All 5 methods enabled"
echo "- Account: li_fan"
echo ""

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_1000reps.R

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Upload SLURM script
    scp temp_slurm_${scenario}_1000rep.sh \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/run_job.sh"
    
    # Submit the job
    echo "Submitting job for $scenario (1000 reps)..."
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu \
             "cd $REMOTE_DIR && sbatch run_job.sh" | awk '{print $4}')
    
    echo "✅ Submitted Job ID: $JOB_ID for $scenario (1000 reps)"
    
    # Clean up local temp files
    rm -f temp_slurm_${scenario}_1000rep.sh
    rm -f "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_1000reps.R"
done

echo ""
echo "==============================================================="
echo "All 1000-REPLICATION jobs submitted to li_fan account!"
echo "==============================================================="
echo ""
echo "Remote directory: $REMOTE_BASE"
echo ""
echo "Configuration:"
echo "✅ Replications: 1000 (10x more than 100-rep run)"
echo "✅ Time limit: 23 hours (day partition)"
echo "✅ Account: li_fan"
echo "✅ All 5 methods enabled"
echo "✅ All fixes from successful runs applied"
echo ""
echo "Expected runtime: ~13-15 hours (based on 100-rep taking ~80 min)"
echo ""
echo "To check status:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=li_fan | grep 1000rep'"
echo ""
echo "To monitor progress:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'for s in CorCor MisCor CorMis MisMis; do echo \"\$s:\"; tail -5 $REMOTE_BASE/\${s}/*.out 2>/dev/null | grep -E \"replicate|Completed\"; done'"
echo ""
echo "To download results when complete:"
echo "for s in CorCor MisCor CorMis MisMis; do"
echo "  scp yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_BASE/\${s}/raw_results_1000reps_\${s}_FIXED_V3.RData pooroverlap_1000rep_\${s}.RData"
echo "  echo \"Downloaded \${s}\""
echo "done"
