#!/bin/bash

echo "==============================================================="
echo "Resubmitting FIXED Scripts to TONG Account"
echo "==============================================================="
echo ""

# Use the same remote directory to overwrite
REMOTE_BASE="/gpfs/gibbs/project/tong/yz2324/pooroverlap_fully_fixed_20rep_20250821_202829"

echo "Remote directory: $REMOTE_BASE"
echo ""
echo "Key fixes applied:"
echo "1. dsmatchATE.R now sourced LAST (after dependencies)"
echo "2. WDSM FULLY_FIXED functions properly named"
echo ""

# Submit each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "=========================================="
    echo "Processing $scenario scenario..."
    echo "=========================================="
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_DIR="$REMOTE_BASE/${scenario}"
    
    # Upload the FIXED comparison script
    echo "Uploading fixed comparison script..."
    scp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Create SLURM script
    cat > temp_slurm_${scenario}_v2.sh << EOF
#!/bin/bash
#SBATCH --job-name=FIXEDv2_${scenario}
#SBATCH --output=${scenario}_fixed_v2_%j.out
#SBATCH --error=${scenario}_fixed_v2_%j.err
#SBATCH --time=04:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

cd $REMOTE_DIR

# Clean up previous attempt
rm -f raw_results_20reps_${scenario}_FULLY_FIXED.RData

# Load R module
module load R

echo "=========================================="
echo "Starting FIXED v2 ${scenario} 20-rep test"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"
echo ""
echo "Critical fix: dsmatchATE.R now sourced LAST"
echo ""

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Upload SLURM script
    scp temp_slurm_${scenario}_v2.sh \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/run_job_v2.sh"
    
    # Submit the job
    echo "Submitting job for $scenario..."
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu \
             "cd $REMOTE_DIR && sbatch run_job_v2.sh" | awk '{print $4}')
    
    echo "✅ Submitted Job ID: $JOB_ID for $scenario"
    
    # Clean up local temp file
    rm -f temp_slurm_${scenario}_v2.sh
done

echo ""
echo "==============================================================="
echo "All FIXED v2 jobs submitted!"
echo "==============================================================="
echo ""
echo "To check status:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep FIXEDv2'"
echo ""
echo "To download results when complete:"
echo "for s in CorCor MisCor CorMis MisMis; do"
echo "  scp yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_BASE/\${s}/raw_results_20reps_\${s}_FULLY_FIXED.RData ."
echo "done"
