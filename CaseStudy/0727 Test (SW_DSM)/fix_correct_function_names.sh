#!/bin/bash

echo "==============================================================="
echo "Correcting WDSM function names to match actual definitions"
echo "==============================================================="
echo ""

# Fix function calls in all FIXED_V3 scripts
for scenario in CorCor MisCor CorMis MisMis; do
    SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R"
    
    if [ -f "$SCRIPT" ]; then
        # Correct the function name (it's _FIXED not _FULLY_FIXED)
        sed -i '' 's/compute_wdsm_method2_ci_FULLY_FIXED/compute_wdsm_method2_ci_FIXED/g' "$SCRIPT"
        
        echo "✅ Corrected function names in $scenario script"
    fi
done

echo ""
echo "Verifying corrections..."
for scenario in CorCor MisCor CorMis MisMis; do
    SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R"
    echo "$scenario: $(grep -c 'compute_wdsm_method2_ci_FIXED' "$SCRIPT") occurrences"
done

