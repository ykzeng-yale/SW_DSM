#!/bin/bash

# Script to update all scenario folders with correct configuration

echo "Updating all scenario-specific scripts..."

# Define scenarios and their descriptions
declare -A scenarios_desc
scenarios_desc["MisCor"]="PS misspecified (no X1:X2), PGS correct"
scenarios_desc["CorMis"]="PS correct (has X1:X2), PGS misspecified (no X1:X2)"
scenarios_desc["MisMis"]="Both PS and PGS misspecified (no X1:X2)"

# Update MisCor, CorMis, and MisMis scenarios
for scenario in MisCor CorMis MisMis; do
    echo "============================================================"
    echo "Updating $scenario scenario..."
    echo "============================================================"
    
    dir="PATE Retrospective Pooroverlap M135 $scenario GLM"
    
    # Update R script
    sed -i '' "s/scenarios <- c(\"CorCor\", \"MisCor\", \"CorMis\", \"MisMis\")/scenarios <- c(\"$scenario\")/g" "$dir/compare_methods_pate_retrospective_mccleary.R"
    sed -i '' "s/pate_retrospective_pooroverlap_comparison_table_misspec.csv/pate_retrospective_pooroverlap_comparison_table_$scenario.csv/g" "$dir/compare_methods_pate_retrospective_mccleary.R"
    sed -i '' "s/pate_retrospective_pooroverlap_comparison_results_misspec.RData/pate_retrospective_pooroverlap_comparison_results_$scenario.RData/g" "$dir/compare_methods_pate_retrospective_mccleary.R"
    sed -i '' "s/pate_retrospective_pooroverlap_comparison_table_CorCor.csv/pate_retrospective_pooroverlap_comparison_table_$scenario.csv/g" "$dir/compare_methods_pate_retrospective_mccleary.R"
    sed -i '' "s/pate_retrospective_pooroverlap_comparison_results_CorCor.RData/pate_retrospective_pooroverlap_comparison_results_$scenario.RData/g" "$dir/compare_methods_pate_retrospective_mccleary.R"
    
    # Update SLURM script
    sed -i '' "s/pate_retro_pooroverlap_m135_corandmis/pate_pooroverlap_$scenario/g" "$dir/run_comparison_mccleary_optimized.sh"
    sed -i '' "s/pate_pooroverlap_CorCor/pate_pooroverlap_$scenario/g" "$dir/run_comparison_mccleary_optimized.sh"
    sed -i '' "s/pate_retrospective_pooroverlap_misspec_%j/pate_retrospective_pooroverlap_${scenario}_%j/g" "$dir/run_comparison_mccleary_optimized.sh"
    sed -i '' "s/pate_retrospective_pooroverlap_CorCor_%j/pate_retrospective_pooroverlap_${scenario}_%j/g" "$dir/run_comparison_mccleary_optimized.sh"
    sed -i '' "s/pate_retrospective_pooroverlap_m135_corandmis/pate_retrospective_pooroverlap_m135_$scenario/g" "$dir/run_comparison_mccleary_optimized.sh"
    sed -i '' "s/pate_retrospective_pooroverlap_m135_CorCor/pate_retrospective_pooroverlap_m135_$scenario/g" "$dir/run_comparison_mccleary_optimized.sh"
    
    # Update submission script
    sed -i '' "s/PATE Retrospective Pooroverlap M135 CorAndMis/PATE Retrospective Pooroverlap M135 $scenario/g" "$dir/submit_to_mccleary.sh"
    sed -i '' "s/PATE Retrospective Pooroverlap M135 CorCor/PATE Retrospective Pooroverlap M135 $scenario/g" "$dir/submit_to_mccleary.sh"
    sed -i '' "s/Poor Overlap Model Misspecification Analysis/Poor Overlap $scenario Scenario/g" "$dir/submit_to_mccleary.sh"
    sed -i '' "s/Poor Overlap CorCor Scenario/Poor Overlap $scenario Scenario/g" "$dir/submit_to_mccleary.sh"
    sed -i '' "s/Scenarios: CorCor, MisCor, CorMis, MisMis/Scenario: ${scenarios_desc[$scenario]}/g" "$dir/submit_to_mccleary.sh"
    sed -i '' "s/Scenario: Both PS and PGS Correct (with X1:X2 interaction)/Scenario: ${scenarios_desc[$scenario]}/g" "$dir/submit_to_mccleary.sh"
    sed -i '' "s/pate_retrospective_pooroverlap_m135_corandmis/pate_retrospective_pooroverlap_m135_$scenario/g" "$dir/submit_to_mccleary.sh"
    sed -i '' "s/pate_retrospective_pooroverlap_m135_CorCor/pate_retrospective_pooroverlap_m135_$scenario/g" "$dir/submit_to_mccleary.sh"
    
    echo "Updated $scenario scenario successfully!"
done

echo "============================================================"
echo "All scenarios updated successfully!"
echo "============================================================"
