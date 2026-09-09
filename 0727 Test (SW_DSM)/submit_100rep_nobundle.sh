#!/bin/bash

echo "==========================================
Submitting 100-REP Jobs WITHOUT bundling
==========================================
"

SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

for scenario in "${SCENARIOS[@]}"; do
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pooroverlap_100rep_nobundle_${TIMESTAMP}/${scenario}"
    
    echo "Processing ${scenario}..."
    
    # Create remote directory
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p ${REMOTE_DIR}"
    
    # Upload files separately (more Duo prompts but more reliable)
    echo "  Uploading comparison script..."
    scp "${LOCAL_DIR}/compare_methods_pate_retrospective_mccleary_100reps_CORRECTED_FINAL_V2.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/compare_methods_pate_retrospective_mccleary_100reps_CORRECTED_FINAL.R"
    
    echo "  Uploading WDSM functions..."
    scp "${LOCAL_DIR}/wdsm_ci_functions.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/"
    scp "${LOCAL_DIR}/wdsm_method2_multinomial_bootstrap.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/"
    
    echo "  Uploading population data..."
    scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData \
        yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/"
    
    echo "  Uploading dsmatch-master..."
    scp -r dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/"
    
    # Create and upload SLURM script
    cat > temp_slurm_${scenario}.sh << SLURM_EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_100rep_nobundle
#SBATCH --output=${scenario}_100rep_nobundle_%j.out
#SBATCH --error=${scenario}_100rep_nobundle_%j.err
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --account=tong

cd ${REMOTE_DIR}

module load R/4.3.2-foss-2022b

echo "=========================================="
echo "Starting 100-REP ${scenario} (no bundle, fixed export)"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"

# Verify dsmatch-master/R exists
if [ -d "dsmatch-master/R" ]; then
    echo "✅ dsmatch-master/R directory found"
    ls -la dsmatch-master/R/*.R | wc -l
    echo "R files found in dsmatch-master/R"
else
    echo "❌ ERROR: dsmatch-master/R directory not found!"
fi

Rscript compare_methods_pate_retrospective_mccleary_100reps_CORRECTED_FINAL.R

echo "Completed at: \$(date)"
echo "=========================================="
SLURM_EOF
    
    scp temp_slurm_${scenario}.sh yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/run_${scenario}.sh"
    
    # Submit job
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd ${REMOTE_DIR} && sbatch run_${scenario}.sh" | awk '{print $4}')
    echo "  ✅ Submitted Job ID: ${JOB_ID} for ${scenario}"
    
    # Clean up
    rm -f temp_slurm_${scenario}.sh
    
    # Add a small delay to avoid overwhelming SSH
    sleep 2
done

echo -e "\n==========================================
All jobs submitted WITHOUT bundling!
Remote directory: /gpfs/gibbs/project/tong/yz2324/pooroverlap_100rep_nobundle_${TIMESTAMP}
==========================================
"
