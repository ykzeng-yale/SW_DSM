#!/bin/bash
# Final fix: remove dsmatchATT.utils.R sourcing and source individual utility files

echo ""
echo "============================================================"
echo "Final Fix: Correct Source Files"
echo "============================================================"

REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_1000rep_20250822"

# Create fix script
cat > final_fix_sources.R << 'EOF'
# Fix source paths in the scripts
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("Please provide script name as argument")
}

script_name <- args[1]
script_content <- readLines(script_name)

# Find the line that sources dsmatchATT.utils.R and replace it
for (i in 1:length(script_content)) {
  # Replace the dsmatchATT.utils.R line with individual utility sources
  if (grepl("dsmatchATT.utils.R", script_content[i])) {
    # Replace with sourcing the utility functions
    script_content[i] <- paste0(
      '  source("', 
      gsub("dsmatchATT.utils.R", "is.lp.R", script_content[i]) %>% 
        gsub('.*source\\("(.+)"\\).*', '\\1', .),
      '")\n',
      '  source("', 
      gsub("dsmatchATT.utils.R", "is.ps.R", script_content[i]) %>% 
        gsub('.*source\\("(.+)"\\).*', '\\1', .),
      '")'
    )
  }
}

# Alternative simpler approach - just comment out the utils line
for (i in 1:length(script_content)) {
  if (grepl("dsmatchATT.utils.R", script_content[i])) {
    # Get the directory path
    if (grepl("/gpfs/", script_content[i])) {
      base_path <- "/gpfs/gibbs/project/tong/yz2324/patt_1000rep_20250822/dsmatch-master/R/"
      # Add individual source lines after the dsmatchATT.R source
      script_content[i-1] <- paste0(
        script_content[i-1], "\n",
        '  source("', base_path, 'is.lp.R")\n',
        '  source("', base_path, 'is.ps.R")'
      )
    } else {
      # Local paths
      script_content[i-1] <- paste0(
        script_content[i-1], "\n",
        '  source("dsmatch-master/R/is.lp.R")\n',
        '  source("dsmatch-master/R/is.ps.R")'
      )
    }
    # Comment out the utils line
    script_content[i] <- paste0("  # ", script_content[i])
  }
}

writeLines(script_content, paste0("final_", script_name))
cat("Fixed:", script_name, "\n")
EOF

# Apply fixes locally
echo "Applying final fixes locally..."
for scenario in CorCor MisCor CorMis MisMis; do
  echo "Fixing ${scenario}..."
  Rscript final_fix_sources.R fixed_comprehensive_patt_comparison_${scenario}_M5_1000rep.R
done

# Upload final fixed scripts
echo "Uploading final fixed scripts to HPC..."
scp final_fixed_comprehensive_patt_comparison_*_M5_1000rep.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

# Create final SLURM scripts
echo "Creating final SLURM scripts..."

for scenario in CorCor MisCor CorMis MisMis; do
cat > run_${scenario}_FINAL.sh << EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_FIN
#SBATCH --output=${scenario}_FINAL_%j.out
#SBATCH --error=${scenario}_FINAL_%j.err
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

module load R/4.3.2-foss-2022b
cd $REMOTE_DIR
Rscript final_fixed_comprehensive_patt_comparison_${scenario}_M5_1000rep.R
EOF
done

# Upload SLURM scripts
echo "Uploading SLURM scripts..."
scp run_*_FINAL.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/

echo ""
echo "============================================================"
echo "FINAL FIX APPLIED:"
echo "1. Removed dsmatchATT.utils.R (doesn't exist)"
echo "2. Added is.lp.R and is.ps.R sourcing"
echo "3. Corrected sampling mechanism (stratified -> cluster -> individual)"
echo "4. Added ones column for sampling"
echo "5. Fixed all paths"
echo "============================================================"
echo ""
echo "Ready to submit: ./submit_final_1000rep.sh"
