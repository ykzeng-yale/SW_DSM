#!/bin/bash

# Fix the missing source of wdsm_method2_multinomial_bootstrap.R in all poor overlap scripts

echo "Fixing missing WDSM source in all poor overlap scenario scripts..."

for scenario in CorCor MisCor CorMis MisMis; do
    echo "Fixing $scenario..."
    
    # The comparison script to fix
    SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_FINAL_NO_M.R"
    
    # Create backup
    cp "$SCRIPT" "${SCRIPT}.backup_missing_source"
    
    # Replace the single source line with both source lines
    # Change:
    # source("wdsm_ci_functions.R")
    # To:
    # source("wdsm_method2_multinomial_bootstrap.R")
    # source("wdsm_ci_functions.R")
    
    sed -i '' 's|^source("wdsm_ci_functions.R")|source("wdsm_method2_multinomial_bootstrap.R")\
source("wdsm_ci_functions.R")|' "$SCRIPT"
    
    echo "  Fixed: $SCRIPT"
done

echo ""
echo "Creating new version with proper WDSM sourcing..."

# Create new PROPERLY_SOURCED version
for scenario in CorCor MisCor CorMis MisMis; do
    echo "Creating PROPERLY_SOURCED version for $scenario..."
    
    OLD_SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_FINAL_NO_M.R"
    NEW_SCRIPT="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_M5_100reps_PROPERLY_SOURCED.R"
    
    cp "$OLD_SCRIPT" "$NEW_SCRIPT"
    
    # Add comment at top of file to indicate this is the properly sourced version
    cat > temp_header.txt << 'EOF'
# PROPERLY_SOURCED VERSION - Fixed missing wdsm_method2_multinomial_bootstrap.R source
# This version correctly sources BOTH:
#   1. wdsm_method2_multinomial_bootstrap.R (contains compute_wdsm_method2_ci)
#   2. wdsm_ci_functions.R (contains wdsm_point_estimate)
EOF
    
    # Combine header with rest of file (skip first line)
    tail -n +2 "$NEW_SCRIPT" > temp_body.txt
    cat temp_header.txt temp_body.txt > "$NEW_SCRIPT"
    rm temp_header.txt temp_body.txt
    
    echo "  Created: $NEW_SCRIPT"
done

echo ""
echo "All scripts fixed! The PROPERLY_SOURCED versions are ready to submit."
