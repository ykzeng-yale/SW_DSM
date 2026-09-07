#!/bin/bash

# Fix dsmatchATT calls in all 10-rep scripts
echo "Fixing dsmatchATT function calls in all 10-rep scripts..."

# Copy the fixed CorCor version to the others
for spec in MisCor CorMis MisMis; do
  echo "Fixing comprehensive_patt_comparison_${spec}_M5_10rep.R..."
  cp comprehensive_patt_comparison_CorCor_M5_10rep.R comprehensive_patt_comparison_${spec}_M5_10rep.R
  
  # Adjust model specification settings for each scenario
  if [ "$spec" == "MisCor" ]; then
    # MisCor: PS misspecified, PGS correct
    sed -i '' 's/model_spec <- "CorCor"/model_spec <- "MisCor"/' comprehensive_patt_comparison_${spec}_M5_10rep.R
    sed -i '' 's/CorCor_M5_10rep/MisCor_M5_10rep/g' comprehensive_patt_comparison_${spec}_M5_10rep.R
  elif [ "$spec" == "CorMis" ]; then
    # CorMis: PS correct, PGS misspecified
    sed -i '' 's/model_spec <- "CorCor"/model_spec <- "CorMis"/' comprehensive_patt_comparison_${spec}_M5_10rep.R
    sed -i '' 's/CorCor_M5_10rep/CorMis_M5_10rep/g' comprehensive_patt_comparison_${spec}_M5_10rep.R
  elif [ "$spec" == "MisMis" ]; then
    # MisMis: Both misspecified
    sed -i '' 's/model_spec <- "CorCor"/model_spec <- "MisMis"/' comprehensive_patt_comparison_${spec}_M5_10rep.R
    sed -i '' 's/CorCor_M5_10rep/MisMis_M5_10rep/g' comprehensive_patt_comparison_${spec}_M5_10rep.R
  fi
done

echo "All 10-rep scripts fixed!"
