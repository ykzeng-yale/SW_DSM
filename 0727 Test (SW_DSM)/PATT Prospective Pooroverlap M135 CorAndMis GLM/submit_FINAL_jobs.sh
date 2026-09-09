#!/bin/bash

# Script to submit FINAL corrected jobs to tong account

REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_FINAL_20250820"

echo "Uploading FINAL scripts..."
rsync -avz --progress \
  comprehensive_patt_comparison_*_M5_10rep_FINAL.R \
  yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Create submission scripts on the server
for MODEL_SPEC in CorCor CorMis MisCor MisMis; do
  
  cat > temp_submit_final.sh << EOF
#!/bin/bash
#SBATCH --job-name=FINAL_${MODEL_SPEC}_10rep
#SBATCH --output=FINAL_${MODEL_SPEC}_10rep_%j.out
#SBATCH --error=FINAL_${MODEL_SPEC}_10rep_%j.err
#SBATCH --cpus-per-task=10
#SBATCH --mem-per-cpu=8G
#SBATCH --time=04:00:00
#SBATCH --partition=day
#SBATCH --account=tong

cd $REMOTE_DIR

module load R/4.4.1-foss-2022b

echo "============================================================"
echo "Job started at: \$(date)"
echo "Running on node: \$(hostname)"
echo "Working directory: \$(pwd)"
echo "Model Specification: ${MODEL_SPEC}"
echo "Version: FINAL - Based on retrospective structure"
echo "============================================================"

Rscript comprehensive_patt_comparison_${MODEL_SPEC}_M5_10rep_FINAL.R

echo "============================================================"
echo "Job completed at: \$(date)"
echo "============================================================"
EOF
  
  # Upload the script
  echo "Uploading script for ${MODEL_SPEC}..."
  scp temp_submit_final.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/run_${MODEL_SPEC}_10rep_FINAL.sh
  
  # Submit the job
  echo "Submitting ${MODEL_SPEC} FINAL job..."
  ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_${MODEL_SPEC}_10rep_FINAL.sh"
  
  rm temp_submit_final.sh
  
done

echo "All FINAL jobs submitted!"
echo "Check status with: squeue --account=tong -u \$USER"
