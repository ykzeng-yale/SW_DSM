#!/bin/bash
# Submit corrected scripts with 1:1 matching for unweighted methods

echo "============================================================"
echo "Submitting CORRECTED Scripts (1:1 Matching for Unweighted)"
echo "============================================================"

# Server details
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"
REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_1to1_matching_20250821/"

echo "Creating remote directory..."
ssh $SERVER "mkdir -p $REMOTE_DIR"

echo "Uploading corrected scripts (1:1 matching for unweighted)..."
rsync -avz comprehensive_patt_comparison_*_M5_100rep_FINAL.R $SERVER:$REMOTE_DIR/

echo "Copying packages and data from previous run..."
ssh $SERVER "cd $REMOTE_DIR && cp -r ../patt_NO_TIMEOUT_20250821/WDSM . && cp -r ../patt_NO_TIMEOUT_20250821/dsmatch-master . && cp ../patt_NO_TIMEOUT_20250821/SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData ."

# Create SLURM scripts
for scenario in CorCor MisCor CorMis MisMis; do
cat > run_${scenario}_1to1.sh << EOF
#!/bin/bash
#SBATCH --job-name=${scenario}_1to1
#SBATCH --output=${scenario}_1to1_%j.out
#SBATCH --error=${scenario}_1to1_%j.err
#SBATCH --time=23:00:00
#SBATCH --partition=day
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=8G
#SBATCH --account=tong

module load R/4.3.2-foss-2022b

cd /gpfs/gibbs/project/tong/yz2324/patt_1to1_matching_20250821/

echo "Starting ${scenario} (1:1 matching) at \$(date)"
echo "Unweighted methods: 1:1 matching with replacement"
echo "WDSM: M=5 matching"
echo "PS Full: Full matching with survey weights"

Rscript comprehensive_patt_comparison_${scenario}_M5_100rep_FINAL.R

echo "Completed ${scenario} at \$(date)"
EOF
done

echo "Uploading SLURM scripts..."
scp run_*_1to1.sh $SERVER:$REMOTE_DIR/

echo "Submitting jobs..."
for scenario in CorCor MisCor CorMis MisMis; do
  echo "Submitting $scenario..."
  ssh $SERVER "cd $REMOTE_DIR && sbatch run_${scenario}_1to1.sh"
done

echo "============================================================"
echo "KEY CHANGES:"
echo "1. DSM/PS/PG: 1:1 matching with replacement (feasible!)"
echo "2. WDSM: Still uses M=5 (designed for it)"
echo "3. PS Full: Full matching (adapts automatically)"
echo "4. NO individual method timeouts"
echo "============================================================"

# Clean up local scripts
rm -f run_*_1to1.sh

echo ""
echo "Monitor: ssh $SERVER 'squeue -u \$USER | grep 1to1'"
echo "Results: ssh $SERVER 'ls -la $REMOTE_DIR*.RData'"
