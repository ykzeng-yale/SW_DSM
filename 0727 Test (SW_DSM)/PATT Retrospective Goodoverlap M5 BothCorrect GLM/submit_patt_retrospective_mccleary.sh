#!/bin/bash
#SBATCH --job-name=patt_retrospective_1000
#SBATCH --output=patt_retrospective_%j.out
#SBATCH --error=patt_retrospective_%j.err
#SBATCH --time=08:00:00           # 8 hours for 1000 replicates
#SBATCH --partition=day           # Use 'day' partition for <24h jobs
#SBATCH --cpus-per-task=22        # 20 for R + 2 overhead
#SBATCH --mem-per-cpu=8G          # 8GB per CPU (total ~176GB)

# ============================================================================
# JOB INFO
# ============================================================================
echo "============================================================"
echo "PATT RETROSPECTIVE COMPARISON (1000 REPLICATES)"
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
# Load R module
module load R/4.3.0-foss-2020b

echo "R version:"
R --version

# Increase stack size and memory limits
ulimit -s unlimited
ulimit -v unlimited

# Prevent nested parallelism
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

# ============================================================================
# RUN R SCRIPT
# ============================================================================
echo "Starting PATT retrospective comparison at: $(date)"
echo "Configuration: 20 cores, FORK cluster"
echo "Methods being compared:"
echo "  1. Unweighted DSM (dsmatch-master)"
echo "  2. Unweighted PS matching (dsmatch-master)"
echo "  3. Unweighted PG matching (dsmatch-master)"
echo "  4. Survey-weighted PS full matching (MatchIt)"
echo "  5. Survey-weighted DSM V2 with standard GLM/LM"
echo "Parameters: 1000 replicates, 200 bootstrap iterations"
echo "Batch size: 100"
echo "Timeout per method: 2 minutes"
echo "============================================================"

Rscript compare_methods_patt_retrospective_mccleary.R

# ============================================================================
# JOB COMPLETION
# ============================================================================
echo "============================================================"
echo "Job completed at: $(date)"
echo "Exit code: $?"
echo "============================================================"