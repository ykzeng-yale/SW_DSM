#!/bin/bash
# Submit all 1000 replicate jobs to HPC
# Based on successful 1:1 matching configuration

echo "=========================================="
echo "Submitting 1000 Replicate PATT Jobs"
echo "Date: $(date)"
echo "=========================================="

# Configuration
REMOTE_USER="yz2324"
REMOTE_HOST="login2.mccleary.ycrc.yale.edu"
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_1000rep_1to1_matching_$(date +%Y%m%d)"

# Create remote directory
echo "Creating remote directory: $REMOTE_DIR"
ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p $REMOTE_DIR"

# Upload R scripts
echo "Uploading R scripts..."
for scenario in CorCor MisCor CorMis MisMis; do
    echo "  - comprehensive_patt_comparison_${scenario}_M5_1000rep_FINAL.R"
    scp "comprehensive_patt_comparison_${scenario}_M5_1000rep_FINAL.R" \
        ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/
done

# Upload supporting files
echo "Uploading supporting files..."
rsync -av --progress \
    dsmatch-master/ \
    ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/dsmatch-master/

rsync -av --progress \
    WDSM/ \
    ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/WDSM/

# Copy data file from existing location
echo "Copying data file on server..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "cp /gpfs/gibbs/project/tong/yz2324/patt_M5_10rep_FINAL_20250820/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData $REMOTE_DIR/"

# Create and upload submission scripts
for scenario in CorCor MisCor CorMis MisMis; do
    cat > run_${scenario}_1000rep.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=SCENARIO_1000rep_1to1
#SBATCH --output=SCENARIO_1000rep_1to1_%j.out
#SBATCH --error=SCENARIO_1000rep_1to1_%j.err
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

# Load R module
module load R/4.4.1-foss-2022b

# Change to working directory
cd REMOTE_DIR

# Run the R script
echo "Starting SCENARIO 1000 replicate simulation with 1:1 matching"
echo "Start time: $(date)"

Rscript comprehensive_patt_comparison_SCENARIO_M5_1000rep_FINAL.R

echo "End time: $(date)"
echo "Job completed"
EOF
    
    # Replace placeholders
    sed -i.bak "s/SCENARIO/${scenario}/g" run_${scenario}_1000rep.sh
    sed -i.bak "s|REMOTE_DIR|${REMOTE_DIR}|g" run_${scenario}_1000rep.sh
    rm run_${scenario}_1000rep.sh.bak
    
    # Upload submission script
    echo "Uploading submission script for ${scenario}..."
    scp run_${scenario}_1000rep.sh ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/
done

# Submit all jobs
echo ""
echo "Submitting jobs to SLURM..."
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Submitting ${scenario}..."
    ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_DIR} && sbatch run_${scenario}_1000rep.sh"
    sleep 2  # Small delay between submissions
done

# Check job status
echo ""
echo "Current job queue:"
ssh ${REMOTE_USER}@${REMOTE_HOST} "squeue -u \$USER | grep 1000rep"

echo ""
echo "=========================================="
echo "All jobs submitted!"
echo "Remote directory: $REMOTE_DIR"
echo ""
echo "To monitor jobs:"
echo "  ssh ${REMOTE_USER}@${REMOTE_HOST} 'squeue -u \$USER | grep 1000rep'"
echo ""
echo "To download results when complete:"
echo "  scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/*_results.RData ."
echo "=========================================="

# Clean up local temp files
rm -f run_*_1000rep.sh
