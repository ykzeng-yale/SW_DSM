#!/bin/bash
# Fix DSM to use SEPARATE covariate matrices for PS and PG models

echo "════════════════════════════════════════════════════════════════"
echo "  FIXING DSM: Separate Covariates for PS and PG Models"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "CRITICAL INSIGHT:"
echo "  DSM needs to fit BOTH PS and PG models"
echo "  They can use DIFFERENT covariate sets!"
echo ""
echo "CORRECT APPROACH:"
echo "  - X parameter: for PS model covariates"
echo "  - lp.pg parameter: for PG model covariates"
echo "  - model.pg = 'linpred': tells DSM to use lp.pg as covariates"
echo ""

# Create the correct DSM code template
cat > fix_dsm_template.txt << 'EOF'
      # Run DSM with bootstrap
      dsm_result <- dsmatchATE(
        Y = Y,
        X = X_ps,  # PS model uses X_ps (with/without interaction)
        A = A,
        method = "dsm",
        model.ps = "logit",  # Fit logit model on X
        model.pg = "linpred",  # Use linear predictors for PG
        lp.pg = X_pg,  # PG model uses X_pg (with/without interaction)
        cov.balance = FALSE,
        varest = TRUE,
        boots = B,
        mc = FALSE,
        ncpus = 1
      )
EOF

echo "Fixing all 1000rep CORRECTED scripts..."
echo ""

for scenario in CorCor MisCor CorMis MisMis; do
    echo "Processing $scenario..."
    
    dir="PATE Retrospective Goodoverlap M5 ${scenario} 1000rep CORRECTED GLM"
    file="$dir/compare_methods_pate_retrospective_mccleary.R"
    
    if [ -f "$file" ]; then
        # Backup current version
        cp "$file" "${file}.DSM_WRONG"
        
        # Fix using sed to replace the DSM block
        sed -i '' '/# Run DSM with bootstrap/,/^[[:space:]]*)/c\
      # Run DSM with bootstrap\
      dsm_result <- dsmatchATE(\
        Y = Y,\
        X = X_ps,  # PS model uses X_ps (with/without interaction)\
        A = A,\
        method = "dsm",\
        model.ps = "logit",  # Fit logit model on X\
        model.pg = "linpred",  # Use linear predictors for PG\
        lp.pg = X_pg,  # PG model uses X_pg (with/without interaction)\
        cov.balance = FALSE,\
        varest = TRUE,\
        boots = B,\
        mc = FALSE,\
        ncpus = 1\
      )' "$file"
        
        echo "  Fixed $scenario"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Verification"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "Checking for correct DSM setup (should find 4 occurrences):"
grep -h "lp.pg = X_pg" PATE*1000rep*CORRECTED*/compare*.R 2>/dev/null | wc -l

echo ""
echo "DSM now correctly uses:"
echo "  - X = X_ps for PS model (with/without X1:X2 based on scenario)"
echo "  - lp.pg = X_pg for PG model (with/without X1:X2 based on scenario)"
echo ""
echo "This allows MisCor to have:"
echo "  - PS without interaction (misspecified)"
echo "  - PG with interaction (correct)"
echo "And CorMis to have:"
echo "  - PS with interaction (correct)"
echo "  - PG without interaction (misspecified)"


