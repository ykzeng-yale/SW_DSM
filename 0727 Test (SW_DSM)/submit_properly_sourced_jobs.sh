#!/bin/bash

echo "==================================================================="
echo "Submitting PROPERLY_SOURCED Poor Overlap Jobs to TONG Account"
echo "==================================================================="
echo ""
echo "These scripts fix the critical missing source issue:"
echo "- Now properly source wdsm_method2_multinomial_bootstrap.R"
echo "- Contains the compute_wdsm_method2_ci function"
echo ""

# Create SLURM scripts and submit jobs
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Processing $scenario..."
    
    # Create SLURM script for this scenario
    cat > "submit_${scenario}_properly_sourced.sh" << EOF
#!/bin/bash
#SBATCH --job-name=PoorOv_${scenario}_PROPER
#SBATCH --output=pate_pooroverlap_${scenario}_properly_sourced_%j.out
#SBATCH --error=pate_pooroverlap_${scenario}_properly_sourced_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=22
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

cd /gpfs/gibbs/project/tong/yz2324/

# Copy necessary files
echo "Copying files for ${scenario}..."
cp -r "PATE Retrospective Pooroverlap M135 ${scenario} GLM" "pate_retrospective_pooroverlap_M5_${scenario}_100reps_PROPERLY_SOURCED"
cd "pate_retrospective_pooroverlap_M5_${scenario}_100reps_PROPERLY_SOURCED"

# Load R module
module load R

echo "Starting R script at: \$(date)"
echo "Scenario: ${scenario}"
echo "Working directory: \$(pwd)"

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R

echo "Completed at: \$(date)"
EOF
    
    # Upload and submit the job
    echo "  Uploading files for $scenario..."
    
    # Create remote directory
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p /gpfs/gibbs/project/tong/yz2324/PATE\ Retrospective\ Pooroverlap\ M135\ ${scenario}\ GLM" 2>/dev/null
    
    # Upload the properly sourced script
    scp "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R" \
        "yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/PATE\ Retrospective\ Pooroverlap\ M135\ ${scenario}\ GLM/"
    
    # Upload the SLURM script
    scp "submit_${scenario}_properly_sourced.sh" \
        "yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/"
    
    # Submit the job
    echo "  Submitting job for $scenario..."
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu "cd /gpfs/gibbs/project/tong/yz2324/ && sbatch submit_${scenario}_properly_sourced.sh" | awk '{print $4}')
    echo "  Submitted Job ID: $JOB_ID"
    echo ""
done

echo "==================================================================="
echo "All PROPERLY_SOURCED jobs submitted!"
echo "==================================================================="
echo ""
echo "To check status:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep PROPER'"
echo ""
echo "To check results when complete:"
echo "for s in CorCor MisCor CorMis MisMis; do"
echo "  scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_pooroverlap_M5_\${s}_100reps_PROPERLY_SOURCED/*.csv pooroverlap_PROPER_\${s}.csv"
echo "done"
