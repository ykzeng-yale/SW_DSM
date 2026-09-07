#!/bin/bash

echo "============================================================"
echo "Submitting CORRECT M5 100-rep scenarios to tong account"
echo "============================================================"

# Create remote directories and upload each scenario
for scenario in CorCor MisCor CorMis MisMis; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    
    echo ""
    echo "Processing $scenario..."
    
    # Create remote directory
    echo "Creating remote directory for M5 $scenario 100rep (tong)..."
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p /gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_100rep_tong"
    
    # Upload the folder contents
    echo "Uploading folder for M5 $scenario 100rep..."
    scp -r "PATE Retrospective Goodoverlap M5 $scenario 100rep GLM"/* yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_100rep_tong/
    
    # Upload population data to this directory
    echo "Uploading population data..."
    scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_100rep_tong/
    
    # Submit the job
    echo "Submitting job for M5 $scenario 100rep to tong account..."
    ssh yz2324@login2.mccleary.ycrc.yale.edu "cd /gpfs/gibbs/project/tong/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_100rep_tong && sbatch run_comparison_mccleary_optimized.sh"
done

echo ""
echo "============================================================"
echo "All M5 100-rep jobs submitted to tong account"
echo "Use 'ssh yz2324@login2.mccleary.ycrc.yale.edu \"squeue -A tong -u yz2324\"' to check status"
echo "============================================================"
