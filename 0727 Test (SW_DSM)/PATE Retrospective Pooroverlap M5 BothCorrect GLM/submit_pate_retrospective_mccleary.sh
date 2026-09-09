#!/bin/bash
#SBATCH --job-name=pate_full_1000
#SBATCH --output=pate_retro_%j.out
#SBATCH --error=pate_retro_%j.err
#SBATCH --time=12:00:00           # 12 hours for 1000 replicates
#SBATCH --partition=day           # Use 'day' partition for jobs <24h
#SBATCH --cpus-per-task=22        # 20 for R + 2 overhead
#SBATCH --mem-per-cpu=8G          # 8GB per CPU (total ~176GB)

# ============================================================================
# JOB INFO
# ============================================================================
echo "============================================================"
echo "PATE RETROSPECTIVE POOR OVERLAP COMPARISON - MCCLEARY HPC"
echo "============================================================"
echo "Job started at: $(date)"
echo "Running on node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "CPUs allocated: $SLURM_CPUS_PER_TASK"
echo "Memory per CPU: 8GB"
echo "Total memory: ~$((SLURM_CPUS_PER_TASK * 8))GB"
echo "============================================================"

cd $SLURM_SUBMIT_DIR

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================
echo "Setting up environment..."

# Load R module
module load R/4.3.0-foss-2020b

echo "R version:"
R --version

# Increase stack size
ulimit -s unlimited
ulimit -v unlimited

# Prevent nested parallelism
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

# ============================================================================
# RUN R SCRIPT
# ============================================================================
echo ""
echo "============================================================"
echo "Starting PATE Retrospective Comparison"
echo "============================================================"
echo "Configuration:"
echo "  - 20 cores (FORK cluster)"
echo "  - 1000 replicates"
echo "  - 5000 sample size (retrospective)"
echo "  - 200 bootstrap iterations"
echo "  - 5 methods: DSM, PG, PS (unweighted), PS Full (weighted), WDSM"
echo "============================================================"
echo ""
echo "Starting R script at: $(date)"

Rscript compare_methods_pate_retrospective_mccleary.R

# ============================================================================
# JOB COMPLETION
# ============================================================================
echo ""
echo "============================================================"
echo "Job completed at: $(date)"
echo "Exit code: $?"
echo "============================================================"

# List output files
echo ""
echo "Output files created:"
ls -lh pate_retrospective_*
echo "============================================================"