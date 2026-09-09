#!/bin/bash
# Prepare and submit 1000-rep jobs with corrected SE ratio calculation

echo "════════════════════════════════════════════════════════════════"
echo "  Preparing 1000-rep Corrected Jobs for li_fan Account"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Create new directories for 1000-rep runs
scenarios=("CorCor" "MisCor" "CorMis" "MisMis")

for scenario in "${scenarios[@]}"; do
    scenario_lower=$(echo "$scenario" | tr '[:upper:]' '[:lower:]')
    
    # Source directory (100-rep version)
    source_dir="PATE Retrospective Goodoverlap M5 ${scenario} 100rep GLM"
    
    # Target directory (1000-rep version)
    target_dir="PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
    
    echo "Processing $scenario..."
    echo "  Creating $target_dir"
    
    # Copy the directory
    cp -r "$source_dir" "$target_dir"
    
    # Update the comparison script
    comparison_script="$target_dir/compare_methods_pate_retrospective_mccleary.R"
    
    echo "  Updating comparison script parameters..."
    
    # Update n_reps to 1000
    sed -i '' 's/n_reps <- 100/n_reps <- 1000/' "$comparison_script"
    
    # Update n_cores to 30
    sed -i '' 's/n_cores <- 20/n_cores <- 30/' "$comparison_script"
    
    # Update batch_size to 100
    sed -i '' 's/batch_size <- 20/batch_size <- 100/' "$comparison_script"
    
    # Add comment about corrected version
    sed -i '' '1s/^/# CORRECTED VERSION - Fixed SE Ratio Calculation\n/' "$comparison_script"
    
    # Update SLURM script
    slurm_script="$target_dir/run_comparison_mccleary_optimized.sh"
    
    echo "  Updating SLURM script..."
    
    # Update SLURM parameters
    sed -i '' 's/#SBATCH --cpus-per-task=.*/#SBATCH --cpus-per-task=30/' "$slurm_script"
    sed -i '' 's/#SBATCH --mem-per-cpu=.*/#SBATCH --mem-per-cpu=8G/' "$slurm_script"
    sed -i '' 's/#SBATCH --time=.*/#SBATCH --time=23:00:00/' "$slurm_script"
    sed -i '' 's/#SBATCH --partition=.*/#SBATCH --partition=day/' "$slurm_script"
    sed -i '' "s/#SBATCH --job-name=.*/#SBATCH --job-name=pate_m5_${scenario_lower}_1000rep_corrected/" "$slurm_script"
    
    # Remove any tong account directive if present
    sed -i '' '/#SBATCH --account=tong/d' "$slurm_script"
    
    # Add li_fan account directive (it's the default, but be explicit)
    if ! grep -q "#SBATCH --account=li_fan" "$slurm_script"; then
        sed -i '' '/^#SBATCH --partition=day$/a\
#SBATCH --account=li_fan
' "$slurm_script"
    fi
    
    echo "  Done with $scenario"
    echo ""
done

echo "════════════════════════════════════════════════════════════════"
echo "  Creating Submission Script"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Create master submission script
cat > submit_1000rep_corrected_to_lifan.sh << 'SUBMIT_EOF'
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
SUBMIT_EOF

chmod +x submit_1000rep_corrected_to_lifan.sh

echo "════════════════════════════════════════════════════════════════"
echo "  Preparation Complete!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Created directories:"
for scenario in "${scenarios[@]}"; do
    echo "  - PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
done
echo ""
echo "Configuration:"
echo "  - Replications: 1000"
echo "  - Cores: 30"
echo "  - Batch size: 100"
echo "  - Time limit: 23 hours"
echo "  - Partition: day"
echo "  - Account: li_fan"
echo ""
echo "To submit all jobs, run:"
echo "  ./submit_1000rep_corrected_to_lifan.sh"
