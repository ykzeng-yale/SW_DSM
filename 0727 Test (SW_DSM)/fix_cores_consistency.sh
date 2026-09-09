#!/bin/bash

echo "Fixing cores consistency across all scripts..."

# Update all comparison scripts to use 12 cores to match SLURM
for scenario in CorCor MisCor CorMis MisMis; do
    SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R"
    
    if [ -f "$SCRIPT" ]; then
        sed -i '' 's/n_cores <- 10/n_cores <- 12/' "$SCRIPT"
        echo "✅ Updated $scenario to use 12 cores"
    fi
done

echo "All scripts updated to use 12 cores consistently with SLURM configuration"
