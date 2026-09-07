#!/bin/bash

echo "==============================================================="
echo "Submitting FINAL CORRECTED Scripts to TONG Account"
echo "==============================================================="
echo ""

# Use new timestamp for this submission
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_BASE="/gpfs/gibbs/project/tong/yz2324/pooroverlap_corrected_5000_${TIMESTAMP}"

echo "Creating new remote directory: $REMOTE_BASE"
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_BASE"

echo ""
echo "CRITICAL FIXES Applied:"
echo "1. Sample size CORRECTED to n=5000 (was 1000)"
echo "2. Functions sourced globally AND in workers"
echo "3. retrospective_sample from wdsm_ci_functions.R"
echo "4. dsmatchATE.R sourced LAST after dependencies"
echo "5. Model specifications correct for each scenario"
echo ""

# Submit each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "=========================================="
    echo "Processing $scenario scenario..."
    echo "=========================================="
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_DIR="$REMOTE_BASE/${scenario}"
    
    # Create remote directory
    echo "Creating remote directory..."
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"
    
    # Upload all necessary files
    echo "Uploading files..."
    
    # Upload comparison script
    scp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R" \
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
    
    # Create SLURM script
    cat > temp_slurm_${scenario}_final.sh << EOF
#!/bin/bash
#SBATCH --job-name=FINAL_${scenario}
#SBATCH --output=${scenario}_final_%j.out
#SBATCH --error=${scenario}_final_%j.err
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
echo "Starting FINAL ${scenario} 20-rep test"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"
echo ""
echo "Critical parameters:"
echo "- Sample size: n=5000 (0.5% of 1,000,000)"
echo "- Scenario: ${scenario}"
echo "- Replicates: 20"
echo "- Bootstrap: 200"
echo "- M: 5"
echo ""

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Upload SLURM script
    scp temp_slurm_${scenario}_final.sh \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/run_job.sh"
    
    # Submit the job
    echo "Submitting job for $scenario..."
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu \
             "cd $REMOTE_DIR && sbatch run_job.sh" | awk '{print $4}')
    
    echo "✅ Submitted Job ID: $JOB_ID for $scenario"
    
    # Clean up local temp file
    rm -f temp_slurm_${scenario}_final.sh
done

echo ""
echo "==============================================================="
echo "All FINAL CORRECTED jobs submitted!"
echo "==============================================================="
echo ""
echo "Remote directory: $REMOTE_BASE"
echo ""
echo "Critical correction: Sample size = 5000 (not 1000)"
echo ""
echo "To check status:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep FINAL'"
echo ""
echo "To download results when complete:"
echo "for s in CorCor MisCor CorMis MisMis; do"
echo "  scp yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_BASE/\${s}/raw_results_20reps_\${s}_FIXED_V3.RData ."
echo "done"
