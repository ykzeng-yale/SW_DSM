#!/bin/bash

echo "==============================================================="
echo "Fixing bootstrap function export name"
echo "==============================================================="
echo ""

# Fix function export in all FIXED_V3 scripts
for scenario in CorCor MisCor CorMis MisMis; do
    SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R"
    
    if [ -f "$SCRIPT" ]; then
        # Correct the bootstrap function name in exports
        sed -i '' 's/"method2_multinomial_bootstrap_ci"/"method2_multinomial_bootstrap_ci_FIXED", "fit_mu_on_scores_bootstrap"/' "$SCRIPT"
        
        echo "✅ Fixed bootstrap export in $scenario script"
    fi
done

echo ""
echo "Bootstrap function exports corrected"

