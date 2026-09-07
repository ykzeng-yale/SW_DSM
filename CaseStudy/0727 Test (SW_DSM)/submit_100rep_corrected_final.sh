#!/bin/bash

# Submit 100-rep jobs with corrected WDSM to tong account

echo "==========================================
Submitting 100-REP Jobs with Corrected WDSM
==========================================
"

SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

for scenario in "${SCENARIOS[@]}"; do
    LOCAL_DIR="PATE Retrospective Pooroverlap M135 ${scenario} GLM"
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/pooroverlap_corrected_100rep_${TIMESTAMP}/${scenario}"
    
    echo "Processing ${scenario}..."
    
    # Create remote directory
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p ${REMOTE_DIR}"
    
    # Upload files
    echo "  Uploading files..."
    scp "${LOCAL_DIR}/compare_methods_pate_retrospective_mccleary_100reps_CORRECTED_FINAL.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/"
    scp "${LOCAL_DIR}/wdsm_ci_functions.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/"
    scp "${LOCAL_DIR}/wdsm_method2_multinomial_bootstrap.R" \
        yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/"
    scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData \
        yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/"
    scp -r dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/"
    
    # Create SLURM script
    cat > temp_slurm_${scenario}_corrected.sh << SLURM_EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_100rep_corrected
#SBATCH --output=${scenario}_100rep_corrected_%j.out
#SBATCH --error=${scenario}_100rep_corrected_%j.err
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --account=tong

cd ${REMOTE_DIR}

module load R/4.3.2-foss-2022b

echo "=========================================="
echo "Starting 100-REP ${scenario} with Corrected WDSM"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"

Rscript compare_methods_pate_retrospective_mccleary_100reps_CORRECTED_FINAL.R

echo "Completed at: \$(date)"
echo "=========================================="
SLURM_EOF
    
    scp temp_slurm_${scenario}_corrected.sh yz2324@login2.mccleary.ycrc.yale.edu:"${REMOTE_DIR}/run_${scenario}.sh"
    
    # Submit job
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd ${REMOTE_DIR} && sbatch run_${scenario}.sh" | awk '{print $4}')
    echo "  ✅ Submitted Job ID: ${JOB_ID} for ${scenario}"
    
    # Clean up
    rm -f temp_slurm_${scenario}_corrected.sh
done

echo -e "\n==========================================
All 100-REP jobs submitted with corrected WDSM!
Remote directory: /gpfs/gibbs/project/tong/yz2324/pooroverlap_corrected_100rep_${TIMESTAMP}
==========================================

Configuration:
✅ Using Good Overlap WDSM functions (with interaction parameters)
✅ Corrected data structure handling (list extraction and column renaming)
✅ 100 replications per scenario
✅ Account: tong
✅ Time limit: 23 hours (day partition)
✅ All model specifications correctly set

To check status:
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep corrected'

To monitor progress:
ssh yz2324@login2.mccleary.ycrc.yale.edu 'for s in CorCor MisCor CorMis MisMis; do echo "\$s:"; tail -5 /gpfs/gibbs/project/tong/yz2324/pooroverlap_corrected_100rep_'${TIMESTAMP}'/\${s}/*.out 2>/dev/null | grep -E "replicate|Completed"; done'
"
