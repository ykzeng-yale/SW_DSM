#!/bin/bash
#SBATCH --job-name=patt_M135_CorAndMis_Poor
#SBATCH --output=patt_M135_CorAndMis_Poor_%j.out
#SBATCH --error=patt_M135_CorAndMis_Poor_%j.err
#SBATCH --time=22:00:00           # 22 hours (4x scenarios × 3x M values)
#SBATCH --partition=day           # Use 'day' partition for <24h jobs
#SBATCH --cpus-per-task=32        # 30 for R + 2 for overhead
#SBATCH --mem-per-cpu=8G          # 8GB per CPU (~256GB total)

# ============================================================================
# JOB INFO
# ============================================================================
echo "============================================================"
echo "COMPREHENSIVE PATT COMPARISON WITH M=1,3,5 AND MODEL SPECIFICATIONS (POOR OVERLAP)"
echo "(1000 REPLICATES, 30 CORES, 4 MODEL SCENARIOS)"
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
# Load R module (adjust version as needed)
module load R/4.3.0-foss-2020b

echo "R version:"
R --version

# Increase stack size and memory limits
ulimit -s unlimited
ulimit -v unlimited

# Prevent nested parallelism (important for stable parallel execution)
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

# ============================================================================
# RUN R SCRIPT
# ============================================================================
echo "Starting PATT comparison with M=1,3,5 and Model Specifications (Poor Overlap) at: $(date)"
echo "Configuration: 30 cores, FORK cluster"
echo "Parameters: 1000 replicates, M=1/3/5 neighbors, 200 bootstrap iterations"
echo "Model Specs: CorCor, MisCor, CorMis, MisMis (4 scenarios)"
echo "Methods: DSM, PG, PS (unweighted) + PS Full, WDSM (survey-weighted)"
echo "Batch size: 100"
echo "Timeout per replicate: 5 minutes (includes all M values and model specs)"
echo "============================================================"

# Run the comprehensive comparison
Rscript comprehensive_patt_comparison_mccleary.R

# ============================================================================
# JOB COMPLETION
# ============================================================================
echo "============================================================"
echo "Job completed at: $(date)"
echo "Exit code: $?"
echo "============================================================"

# List output files
echo "Output files generated:"
ls -lh comprehensive_patt_comparison_M* 2>/dev/null || echo "No output files found"
echo "============================================================"