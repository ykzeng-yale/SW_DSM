#!/bin/bash

echo "==============================================================="
echo "Submitting 20-Rep FULLY FIXED Test to TONG Account"
echo "==============================================================="
echo ""

# Create remote directory for this test run
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_BASE="/gpfs/gibbs/project/tong/yz2324/pooroverlap_fully_fixed_20rep_${TIMESTAMP}"

echo "Creating remote directory: $REMOTE_BASE"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_BASE"

# Submit each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo ""
    echo "=========================================="
    echo "Processing $scenario scenario..."
    echo "=========================================="
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_DIR="$REMOTE_BASE/${scenario}"
    
    # Create remote directory
    echo "Creating remote directory..."
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"
    
    # Upload files
    echo "Uploading files..."
    
    # Upload comparison script
    scp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Upload FULLY FIXED WDSM functions
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
    
    # Create SLURM script
    cat > temp_slurm_${scenario}.sh << EOF
#!/bin/bash
#SBATCH --job-name=FIXED_${scenario}_20
#SBATCH --output=${scenario}_fully_fixed_20rep_%j.out
#SBATCH --error=${scenario}_fully_fixed_20rep_%j.err
#SBATCH --time=04:00:00
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
echo "Starting FULLY FIXED ${scenario} 20-rep test"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"
echo ""
echo "Key fixes applied:"
echo "1. Lambda_ij corrected for survey-weighted imputation"
echo "2. Separate S0/S1 score spaces"
echo "3. Outcome models fitted on scores"
echo "4. Treatment-aware bootstrap"
echo ""

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Upload SLURM script
    scp temp_slurm_${scenario}.sh \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/run_job.sh"
    
    # Submit the job
    echo "Submitting job for $scenario..."
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu \
             "cd $REMOTE_DIR && sbatch run_job.sh" | awk '{print $4}')
    
    echo "✅ Submitted Job ID: $JOB_ID for $scenario"
    
    # Clean up local temp file
    rm -f temp_slurm_${scenario}.sh
done

echo ""
echo "==============================================================="
echo "All FULLY FIXED 20-rep test jobs submitted!"
echo "==============================================================="
echo ""
echo "Remote directory: $REMOTE_BASE"
echo ""
echo "Expected improvements with fixes:"
echo "• Bias: 3% → <1% (lambda_ij fix)"
echo "• Coverage: 79% → ~93-95% (score-based refitting)"
echo "• SE Ratio: 0.63 → ~0.95-1.05 (treatment-aware bootstrap)"
echo ""
echo "To check status:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep FIXED'"
echo ""
echo "To download results when complete:"
echo "for s in CorCor MisCor CorMis MisMis; do"
echo "  scp yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_BASE/\${s}/raw_results_20reps_\${s}_FULLY_FIXED.RData ."
echo "done"
