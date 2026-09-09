#!/bin/bash
#SBATCH --job-name=PoorOv_CorMis_PROPER
#SBATCH --output=pate_pooroverlap_CorMis_properly_sourced_%j.out
#SBATCH --error=pate_pooroverlap_CorMis_properly_sourced_%j.err
#SBATCH --time=22:00:00
#SBATCH --partition=day
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=22
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

cd /gpfs/gibbs/project/tong/yz2324/

# Copy necessary files
echo "Copying files for CorMis..."
cp -r "PATE Retrospective Pooroverlap M135 CorMis GLM" "pate_retrospective_pooroverlap_M5_CorMis_100reps_PROPERLY_SOURCED"
cd "pate_retrospective_pooroverlap_M5_CorMis_100reps_PROPERLY_SOURCED"

# Load R module
module load R

echo "Starting R script at: $(date)"
echo "Scenario: CorMis"
echo "Working directory: $(pwd)"

# Run the R script
Rscript compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R

echo "Completed at: $(date)"
