#!/bin/bash

echo "==============================================================="
echo "Submitting FIXED v3 Scripts to TONG Account"
echo "==============================================================="
echo ""

# Use the same remote directory to overwrite
REMOTE_BASE="/gpfs/gibbs/project/tong/yz2324/pooroverlap_fully_fixed_20rep_20250821_202829"

echo "Remote directory: $REMOTE_BASE"
echo ""
echo "Key fixes in v3:"
echo "1. Follows Good Overlap structure exactly"
echo "2. Sources functions globally AND in workers"
echo "3. Uses retrospective_sample from wdsm_ci_functions.R"
echo "4. dsmatchATE.R sourced LAST after dependencies"
echo ""

# Submit each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "=========================================="
    echo "Processing $scenario scenario..."
    echo "=========================================="
    
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_DIR="$REMOTE_BASE/${scenario}"
    
    # Upload the FIXED v3 comparison script
    echo "Uploading FIXED v3 comparison script..."
    scp "$LOCAL_DIR/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Create SLURM script
    cat > temp_slurm_${scenario}_v3.sh << EOF
#!/bin/bash
#SBATCH --job-name=FIXv3_${scenario}
#SBATCH --output=${scenario}_fixed_v3_%j.out
#SBATCH --error=${scenario}_fixed_v3_%j.err
#SBATCH --time=04:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

cd $REMOTE_DIR

# Clean up previous attempts
rm -f raw_results_20reps_${scenario}_*.RData
rm -f parallel_log.txt

# Load R module
module load R

echo "=========================================="
echo "Starting FIXED v3 ${scenario} 20-rep test"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"
echo ""
echo "Critical fixes in v3:"
echo "1. Functions sourced globally AND in workers"
echo "2. retrospective_sample from wdsm_ci_functions.R"
echo "3. dsmatchATE.R sourced LAST"
echo "4. Better error handling"
echo ""

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Upload SLURM script
    scp temp_slurm_${scenario}_v3.sh \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/run_job_v3.sh"
    
    # Submit the job
    echo "Submitting job for $scenario..."
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu \
             "cd $REMOTE_DIR && sbatch run_job_v3.sh" | awk '{print $4}')
    
    echo "✅ Submitted Job ID: $JOB_ID for $scenario"
    
    # Clean up local temp file
    rm -f temp_slurm_${scenario}_v3.sh
done

echo ""
echo "==============================================================="
echo "All FIXED v3 jobs submitted!"
echo "==============================================================="
echo ""
echo "To check status:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep FIXv3'"
echo ""
echo "To download results when complete:"
echo "for s in CorCor MisCor CorMis MisMis; do"
echo "  scp yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_BASE/\${s}/raw_results_20reps_\${s}_FIXED_V3.RData ."
echo "done"
