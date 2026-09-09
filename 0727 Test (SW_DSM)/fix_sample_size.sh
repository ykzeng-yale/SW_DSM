#!/bin/bash

echo "==============================================================="
echo "Fixing sample size from 1000 to 5000 in all scripts"
echo "==============================================================="
echo ""

# Fix sample size in all FIXED_V3 scripts
for scenario in CorCor MisCor CorMis MisMis; do
    SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R"
    
    if [ -f "$SCRIPT" ]; then
        # Fix the sample size from 1000 to 5000
        sed -i '' 's/n_sample <- 1000/n_sample <- 5000/' "$SCRIPT"
        
        echo "✅ Fixed sample size in $scenario script"
        
        # Verify the change
        grep "n_sample <- " "$SCRIPT" | head -1
    fi
done

echo ""
echo "Sample size corrected to 5000 (matching original simulation)"
echo "This represents 0.5% sampling rate from population of 1,000,000"
