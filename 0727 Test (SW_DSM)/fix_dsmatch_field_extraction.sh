#!/bin/bash

echo "==============================================================="
echo "Fixing dsmatchATE Field Extraction in Poor Overlap Scripts"
echo "==============================================================="
echo ""
echo "Changing from wrong field names to correct field names:"
echo "  treatment.effect → est.ds/est.pg/est.ps"
echo "  standard.error → sqrt(bootvar[1,1])"
echo "  CI[1], CI[2] → calculated from bootvar"
echo ""

# Fix all four scenario scripts
for scenario in CorCor MisCor CorMis MisMis; do
    SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_20reps_FULLY_FIXED_V3.R"
    
    if [ -f "$SCRIPT" ]; then
        echo "Fixing $scenario script..."
        
        # Create backup
        cp "$SCRIPT" "${SCRIPT}.backup_field_fix"
        
        # Fix DSM result extraction
        sed -i '' 's/estimate = dsm_result\$treatment.effect/estimate = dsm_result$est.ds/' "$SCRIPT"
        sed -i '' 's/se = dsm_result\$standard.error/se = sqrt(dsm_result$bootvar[1,1])/' "$SCRIPT"
        sed -i '' 's/ci_lower = dsm_result\$CI\[1\]/ci_lower = dsm_result$est.ds - qnorm(1 - alpha\/2) * sqrt(dsm_result$bootvar[1,1])/' "$SCRIPT"
        sed -i '' 's/ci_upper = dsm_result\$CI\[2\]/ci_upper = dsm_result$est.ds + qnorm(1 - alpha\/2) * sqrt(dsm_result$bootvar[1,1])/' "$SCRIPT"
        
        # Fix PG result extraction
        sed -i '' 's/estimate = pg_result\$treatment.effect/estimate = pg_result$est.pg/' "$SCRIPT"
        sed -i '' 's/se = pg_result\$standard.error/se = sqrt(pg_result$bootvar[1,1])/' "$SCRIPT"
        sed -i '' 's/ci_lower = pg_result\$CI\[1\]/ci_lower = pg_result$est.pg - qnorm(1 - alpha\/2) * sqrt(pg_result$bootvar[1,1])/' "$SCRIPT"
        sed -i '' 's/ci_upper = pg_result\$CI\[2\]/ci_upper = pg_result$est.pg + qnorm(1 - alpha\/2) * sqrt(pg_result$bootvar[1,1])/' "$SCRIPT"
        
        # Fix PS result extraction
        sed -i '' 's/estimate = ps_result\$treatment.effect/estimate = ps_result$est.ps/' "$SCRIPT"
        sed -i '' 's/se = ps_result\$standard.error/se = sqrt(ps_result$bootvar[1,1])/' "$SCRIPT"
        sed -i '' 's/ci_lower = ps_result\$CI\[1\]/ci_lower = ps_result$est.ps - qnorm(1 - alpha\/2) * sqrt(ps_result$bootvar[1,1])/' "$SCRIPT"
        sed -i '' 's/ci_upper = ps_result\$CI\[2\]/ci_upper = ps_result$est.ps + qnorm(1 - alpha\/2) * sqrt(ps_result$bootvar[1,1])/' "$SCRIPT"
        
        echo "✅ Fixed $scenario"
    fi
done

echo ""
echo "Field extraction fixed in all scripts!"
echo "Backups created with .backup_field_fix extension"
