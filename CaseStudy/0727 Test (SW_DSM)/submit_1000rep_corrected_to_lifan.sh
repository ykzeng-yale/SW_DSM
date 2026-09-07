#!/bin/bash
# Submit 1000-rep corrected jobs to li_fan account

echo "Submitting 1000-rep corrected jobs to McCleary (li_fan account)..."
echo ""

scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

# Create remote directories and upload
for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    local_dir="PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
    remote_dir="/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_corrected"
    
    echo "Processing $scenario..."
    
    # Create remote directory
    echo "  Creating remote directory..."
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $remote_dir"
    
    # Upload the folder
    echo "  Uploading files..."
    scp -r "$local_dir"/* yz2324@login2.mccleary.ycrc.yale.edu:"$remote_dir/"
    
    # Upload population data
    echo "  Uploading population data..."
    scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData \
        yz2324@login2.mccleary.ycrc.yale.edu:"$remote_dir/"
    
    echo ""
done

# Submit jobs
echo "Submitting jobs..."
ssh yz2324@login2.mccleary.ycrc.yale.edu << 'SSH_EOF'
echo "Submitting from McCleary..."

scenarios=("CorCor" "MisCor" "CorMis" "MisMis")
job_ids=""

for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    work_dir="/gpfs/gibbs/project/li_fan/yz2324/pate_retrospective_goodoverlap_m5_${scenario_lower}_1000rep_corrected"
    
    echo "Submitting $scenario job..."
    cd "$work_dir"
    job_output=$(sbatch run_comparison_mccleary_optimized.sh)
    job_id=$(echo $job_output | awk '{print $4}')
    echo "  Job ID: $job_id"
    job_ids="$job_ids $job_id"
done

echo ""
echo "All jobs submitted!"
echo "Job IDs:$job_ids"
echo ""
echo "Check status with: squeue -u yz2324"
SSH_EOF

echo ""
echo "Submission complete!"
