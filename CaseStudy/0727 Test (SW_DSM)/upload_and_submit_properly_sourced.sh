#!/bin/bash

echo "==================================================================="
echo "Uploading and Submitting PROPERLY_SOURCED Scripts"
echo "==================================================================="
echo ""

# First, create a tar archive with all necessary files
echo "Creating archive of all necessary files..."

tar -czf properly_sourced_pooroverlap.tar.gz \
    "PATE Retrospective Pooroverlap M135 CorCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R" \
    "PATE Retrospective Pooroverlap M135 MisCor GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R" \
    "PATE Retrospective Pooroverlap M135 CorMis GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R" \
    "PATE Retrospective Pooroverlap M135 MisMis GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R" \
    "PATE Retrospective Pooroverlap M135 CorCor GLM/wdsm_method2_multinomial_bootstrap.R" \
    "PATE Retrospective Pooroverlap M135 CorCor GLM/wdsm_ci_functions.R" \
    "dsmatch-master" \
    "SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData" 2>/dev/null

echo "Archive created."
echo ""

# Upload the archive
echo "Uploading archive to server..."
scp properly_sourced_pooroverlap.tar.gz yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/

# Extract and organize on server
echo ""
echo "Extracting and organizing files on server..."

ssh yz2324@login2.mccleary.ycrc.yale.edu << 'REMOTE_COMMANDS'
cd /gpfs/gibbs/project/tong/yz2324/

# Extract the archive
tar -xzf properly_sourced_pooroverlap.tar.gz

# Create new directories for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Setting up $scenario..."
    
    # Create new directory for this run
    DIR="pooroverlap_properly_sourced_${scenario}_100reps"
    rm -rf "$DIR"
    mkdir -p "$DIR"
    
    # Copy the comparison script
    cp "PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R" \
       "$DIR/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R"
    
    # Copy WDSM functions (use CorCor versions for all)
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/wdsm_method2_multinomial_bootstrap.R" "$DIR/"
    cp "PATE Retrospective Pooroverlap M135 CorCor GLM/wdsm_ci_functions.R" "$DIR/"
    
    # Copy dsmatch-master
    cp -r dsmatch-master "$DIR/"
    
    # Copy data
    cp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData "$DIR/"
    
    echo "  Directory $DIR ready."
done

echo "All directories prepared."
REMOTE_COMMANDS

echo ""
echo "Creating and submitting SLURM jobs..."

# Create and submit jobs for each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    echo ""
    echo "Creating job for $scenario..."
    
    # Create SLURM script
    cat > "submit_${scenario}_properly_sourced_v2.sh" << EOF
#!/bin/bash
#SBATCH --job-name=Poor_${scenario}_PROP
#SBATCH --output=pooroverlap_properly_sourced_${scenario}_%j.out
#SBATCH --error=pooroverlap_properly_sourced_${scenario}_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=22
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

cd /gpfs/gibbs/project/tong/yz2324/pooroverlap_properly_sourced_${scenario}_100reps

# Load R module
module load R

echo "=========================================="
echo "Starting PROPERLY_SOURCED ${scenario} job"
echo "=========================================="
echo "Job ID: \$SLURM_JOB_ID"
echo "Starting at: \$(date)"
echo "Working directory: \$(pwd)"
echo ""
echo "Files in directory:"
ls -la
echo ""

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R

echo ""
echo "Completed at: \$(date)"
echo "=========================================="
EOF
    
    # Upload SLURM script
    scp "submit_${scenario}_properly_sourced_v2.sh" \
        yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/
    
    # Submit the job
    echo "Submitting job for $scenario..."
    JOB_ID=$(ssh yz2324@login2.mccleary.ycrc.yale.edu \
             "cd /gpfs/gibbs/project/tong/yz2324/ && sbatch submit_${scenario}_properly_sourced_v2.sh" | awk '{print $4}')
    echo "✅ Submitted Job ID: $JOB_ID for $scenario"
done

echo ""
echo "==================================================================="
echo "All PROPERLY_SOURCED jobs uploaded and submitted!"
echo "==================================================================="
echo ""
echo "New directory structure:"
echo "  pooroverlap_properly_sourced_CorCor_100reps/"
echo "  pooroverlap_properly_sourced_MisCor_100reps/"
echo "  pooroverlap_properly_sourced_CorMis_100reps/"
echo "  pooroverlap_properly_sourced_MisMis_100reps/"
echo ""
echo "Each directory contains:"
echo "  - compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R"
echo "  - wdsm_method2_multinomial_bootstrap.R (✅ NOW INCLUDED)"
echo "  - wdsm_ci_functions.R"
echo "  - dsmatch-master/"
echo "  - SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData"
echo ""
echo "To check status:"
echo "ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -u \$USER --account=tong | grep PROP'"
