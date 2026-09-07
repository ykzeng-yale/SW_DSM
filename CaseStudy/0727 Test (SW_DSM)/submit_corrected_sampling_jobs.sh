#!/bin/bash

echo "==============================================================="
echo "Submitting CORRECTED SAMPLING Jobs to TONG Account"
echo "==============================================================="
echo ""

# Submit each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "----------------------------------------"
    echo "Submitting $scenario scenario..."
    echo "----------------------------------------"
    
    DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pooroverlap_corrected_sampling_${scenario}_100reps"
    
    # Create remote directory and upload files
    echo "Creating remote directory and uploading files..."
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"
    
    # Upload the corrected comparison script
    scp "$DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Upload WDSM functions
    scp "$DIR/wdsm_method2_multinomial_bootstrap.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    scp "$DIR/wdsm_ci_functions.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Upload dsmatch-master directory
    scp -r dsmatch-master \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Upload data
    scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData \
        yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/"
    
    # Create and upload SLURM script
    cat > temp_slurm.sh << EOF
#!/bin/bash
#SBATCH --job-name=Poor_${scenario}_CORR
#SBATCH --output=pooroverlap_corrected_${scenario}_%j.out
#SBATCH --error=pooroverlap_corrected_${scenario}_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=22
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

cd $REMOTE_DIR

# Load R module
module load R

echo "=========================================="
echo "Starting CORRECTED SAMPLING ${scenario} job"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"
echo ""
echo "Files in directory:"
ls -la
echo ""

# Run the R script with corrected sampling
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps_CORRECTED_SAMPLING.R

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    scp temp_slurm.sh yz2324@login2.mccleary.ycrc.yale.edu:"$REMOTE_DIR/run_job.sh"
    
    # Submit the job
    echo "Submitting job..."
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu \
             "cd $REMOTE_DIR && sbatch run_job.sh" | awk '{print $4}')
    
    echo "✅ Submitted Job ID: $JOB_ID for $scenario"
    echo ""
done

# Clean up
rm -f temp_slurm.sh

echo "==============================================================="
echo "All CORRECTED SAMPLING jobs submitted!"
echo "==============================================================="
echo ""
echo "Key differences in corrected version:"
echo "1. Uses probability-based sampling: P(S=1) = expit(c0 + delta_z*A + c1*X1 + ...)"
echo "2. Survey weights = 1/Prob (unique for each unit)"
echo "3. Sampling depends on covariates and treatment"
echo "4. No fixed 50/50 stratification"
echo ""
echo "This matches the original SW_PSW-main implementation exactly."
echo ""
echo "To check job status:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep CORR'"
