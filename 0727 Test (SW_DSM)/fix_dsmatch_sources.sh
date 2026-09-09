#!/bin/bash

# Fix dsmatch sourcing in all poor overlap scenarios

SCENARIOS=("CorCor" "MisCor" "CorMis" "MisMis")

echo "Fixing dsmatch source files..."

for scenario in "${SCENARIOS[@]}"; do
    echo "Fixing $scenario..."
    
    FILE="PATE Retrospective Pooroverlap M135 ${scenario} GLM/compare_methods_pate_retrospective_mccleary_100reps_WALD_CI.R"
    
    # Replace the incorrect source statements with the correct ones
    cat > temp_fix.txt << 'EOF'
# Source dsmatch functions globally (Good Overlap approach)
dsmatch_files <- c(
  "dsmatch-master/R/bisect.R",
  "dsmatch-master/R/is.lp.R",
  "dsmatch-master/R/is.ps.R", 
  "dsmatch-master/R/is.pg.R",
  "dsmatch-master/R/estforboot_dsATE.R",
  "dsmatch-master/R/estforboot_psATE.R",
  "dsmatch-master/R/estforboot_pgATE.R",
  "dsmatch-master/R/estforboot_covATE.R",
  "dsmatch-master/R/dsmatchATE.R"
)
for (file in dsmatch_files) {
  source(file)
}
EOF
    
    # Replace the old sourcing block
    sed -i '' '/# Source dsmatch functions globally/,/source("dsmatch-master\/R\/dsmatchATE.R")/ {
        r temp_fix.txt
        d
    }' "$FILE"
    
    # Also fix inside the worker function
    cat > temp_fix2.txt << 'EOF'
    # Source functions inside worker (CRITICAL for PSOCK clusters)
    dsmatch_files <- c(
      "dsmatch-master/R/bisect.R",
      "dsmatch-master/R/is.lp.R",
      "dsmatch-master/R/is.ps.R", 
      "dsmatch-master/R/is.pg.R",
      "dsmatch-master/R/estforboot_dsATE.R",
      "dsmatch-master/R/estforboot_psATE.R",
      "dsmatch-master/R/estforboot_pgATE.R",
      "dsmatch-master/R/estforboot_covATE.R",
      "dsmatch-master/R/dsmatchATE.R"
    )
    for (file in dsmatch_files) {
      source(file)
    }
EOF
    
    # Replace inside worker
    sed -i '' '/# Source functions inside worker/,/source("dsmatch-master\/R\/dsmatchATE.R")/ {
        r temp_fix2.txt
        d
    }' "$FILE"
    
    echo "✅ Fixed $scenario"
done

rm -f temp_fix.txt temp_fix2.txt

echo "All dsmatch source statements fixed!"
