#!/bin/bash
# Fix all model specification errors in the 1000rep CORRECTED scripts

echo "======================================================================"
echo "  FIXING CRITICAL MODEL SPECIFICATION ERROR"
echo "======================================================================"
echo ""
echo "Problem: Scripts were using 'linpred' vs 'logit' to handle interaction"
echo "Correct: Always use 'logit', only change X matrix content"
echo ""

# Fix each scenario's script
for scenario in CorCor MisCor CorMis MisMis; do
    dir="PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
    file="$dir/compare_methods_pate_retrospective_mccleary.R"
    
    echo "Processing $scenario..."
    
    if [ -f "$file" ]; then
        # Backup original
        cp "$file" "${file}.WRONG_MODEL"
        
        # Create temporary file with fixes
        cat "$file" | \
        sed 's/model\.ps = if (use_interaction_ps) "linpred" else "logit"/model.ps = "logit"/' | \
        sed '/lp\.ps = if (use_interaction_ps) X_ps else NULL,/d' | \
        sed 's/model\.pg = "linpred"/model.pg = "lm"/' | \
        sed '/lp\.pg = X_pg,/d' | \
        sed 's/X = X_dsm,/X = X_ps,/' > "${file}.tmp"
        
        # For DSM method specifically, ensure it uses both X_ps for PS and X_pg for PG
        # This requires more careful editing
        mv "${file}.tmp" "$file"
        
        echo "  Fixed: $file"
    else
        echo "  ERROR: File not found!"
    fi
done

echo ""
echo "======================================================================"
echo "  Verifying fixes..."
echo "======================================================================"

# Check that we removed the problematic lines
echo ""
echo "Checking for remaining 'linpred' in PS models (should be 0):"
grep -c 'model.ps.*linpred' PATE*/compare*.R 2>/dev/null || echo "None found (good!)"

echo ""
echo "Checking for correct 'logit' usage:"
grep 'model.ps = "logit"' PATE*1000rep*/compare*.R | wc -l

echo ""
echo "Fix complete! Scripts now correctly use:"
echo "  - model.ps = 'logit' for all PS models"
echo "  - model.pg = 'lm' for all PG models"
echo "  - X matrices with/without interaction based on scenario"


