#!/bin/bash

# Script to submit 100-rep FINAL jobs to tong account

REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_M5_100rep_FINAL_20250820"

echo "Creating directory for 100-rep jobs..."
ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"

echo "Uploading 100-rep FINAL scripts..."
rsync -avz --progress \
  comprehensive_patt_comparison_*_M5_100rep_FINAL.R \
  yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo "Copying WDSM and dsmatch folders..."
ssh yz2324@login2.mccleary.ycrc.yale.edu "cp -r /gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_FINAL_20250820/WDSM $REMOTE_DIR/"
ssh yz2324@login2.mccleary.ycrc.yale.edu "cp -r /gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_FINAL_20250820/dsmatch-master $REMOTE_DIR/"

echo "Copying data file..."
ssh yz2324@login2.mccleary.ycrc.yale.edu "cp /gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_FINAL_20250820/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData $REMOTE_DIR/"

# Create submission scripts on the server
for MODEL_SPEC in CorCor CorMis MisCor MisMis; do
  
  cat > temp_submit_100rep.sh << EOF
#!/bin/bash
#SBATCH --job-name=FINAL_${MODEL_SPEC}_100rep
#SBATCH --output=FINAL_${MODEL_SPEC}_100rep_%j.out
#SBATCH --error=FINAL_${MODEL_SPEC}_100rep_%j.err
#SBATCH --cpus-per-task=20
#SBATCH --mem-per-cpu=8G
#SBATCH --time=08:00:00
#SBATCH --partition=day
#SBATCH --account=tong

cd $REMOTE_DIR

module load R/4.4.1-foss-2022b

echo "============================================================"
echo "Job started at: \$(date)"
echo "Running on node: \$(hostname)"
echo "Working directory: \$(pwd)"
echo "Model Specification: ${MODEL_SPEC}"
echo "Version: 100-rep FINAL - All methods working"
echo "============================================================"

Rscript comprehensive_patt_comparison_${MODEL_SPEC}_M5_100rep_FINAL.R

echo "============================================================"
echo "Job completed at: \$(date)"
echo "============================================================"
EOF
  
  # Upload the script
  echo "Uploading script for ${MODEL_SPEC}..."
  scp temp_submit_100rep.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/run_${MODEL_SPEC}_100rep_FINAL.sh
  
  # Submit the job
  echo "Submitting ${MODEL_SPEC} 100-rep FINAL job..."
  ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_${MODEL_SPEC}_100rep_FINAL.sh"
  
  rm temp_submit_100rep.sh
  
done

echo "All 100-rep FINAL jobs submitted!"
echo "Check status with: squeue --account=tong -u \$USER"
