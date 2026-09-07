#!/bin/bash

echo "Fixing dsmatch sourcing order in all comparison scripts..."

# Fix the order in all 20-rep scripts
for scenario in CorCor MisCor CorMis MisMis; do
    SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED.R"
    
    if [ -f "$SCRIPT" ]; then
        # Create a backup
        cp "$SCRIPT" "${SCRIPT}.backup"
        
        # Fix the sourcing order - dsmatchATE.R should be LAST
        sed -i '' '/dsmatch_files <- c(/,/)/ {
            s|"dsmatch-master/R/dsmatchATE.R",||
            s|"dsmatch-master/R/estforboot_covATE.R"|"dsmatch-master/R/estforboot_covATE.R",\
      "dsmatch-master/R/dsmatchATE.R"|
        }' "$SCRIPT"
        
        echo "✅ Fixed sourcing order in $scenario"
    fi
done

echo ""
echo "All scripts updated with correct dsmatch sourcing order!"
echo "dsmatchATE.R is now loaded LAST after all its dependencies."
