#!/bin/bash

echo "================================================================"
echo "SYSTEMATIC COVARIATE VERIFICATION FOR ALL QUESTIONS"
echo "================================================================"
echo ""

for q in 1 2 3 4 5 7 10 11 12 13; do
    if [ $q -eq 1 ]; then
        file="Q1_B200_FINAL.R"
    elif [ $q -eq 2 ]; then
        file="Q2_GENDER_MARIJUANA_B200.R"
    elif [ $q -eq 3 ]; then
        file="Q3_EMPLOYMENT_ALCOHOL_B200.R"
    elif [ $q -eq 4 ]; then
        file="Q4_AGE_MARIJUANA_B200.R"
    elif [ $q -eq 5 ]; then
        file="Q5_EDUCATION_ALCOHOL_B200.R"
    elif [ $q -eq 7 ]; then
        file="Q7_RACE_ALCOHOL_B200.R"
    elif [ $q -eq 10 ]; then
        file="Q10_HISPANIC_ALCOHOL_B200.R"
    elif [ $q -eq 11 ]; then
        file="Q11_GENDER_BINGE_B200.R"
    elif [ $q -eq 12 ]; then
        file="Q12_URBAN_ALCOHOL_B200.R"
    elif [ $q -eq 13 ]; then
        file="Q13_INCOME_MRJ_B200_CLEAN.R"
    fi
    
    echo "=== Q$q: $(grep "^#'" Analysis/Scripts/$file | head -1 | cut -d"'" -f2) ==="
    
    # Check treatment variable
    echo "Treatment: $(grep 'A <- d\$' Analysis/Scripts/$file | head -1)"
    
    # Check X matrix
    echo "X matrix: $(grep 'X <- as.matrix' Analysis/Scripts/$file | cut -d'[' -f2 | cut -d']' -f1)"
    
    # Check formulas
    echo "PS formula: $(grep 'ps_f <-' Analysis/Scripts/$file | head -1 | cut -d'"' -f2)"
    echo "PGS formula: $(grep 'pgs_f <-' Analysis/Scripts/$file | head -1 | cut -d'"' -f2)"
    
    # Check PS Full outcome model
    echo "PS Full model: $(grep 'fit <- lm' Analysis/Scripts/$file | grep -o 'Treatment \* ([^)]*)')"
    
    echo ""
done
