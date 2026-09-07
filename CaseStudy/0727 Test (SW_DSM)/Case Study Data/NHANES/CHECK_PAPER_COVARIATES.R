################################################################################
# CHECK EXACT COVARIATES FROM EACH PAPER
# Verify availability in our nhanes_2007_2018.rda dataset
################################################################################

library(dplyr)
library(haven)

load('data/nhanes_2007_2018.rda')

nhanes_clean <- nhanes_2007_2018 %>% 
  mutate(across(where(is.labelled), as.numeric))

all_vars <- tolower(names(nhanes_clean))

cat('=== CHECKING COVARIATES FROM 4 SPECIFIC PAPERS ===\n\n')

check_var <- function(var_name) {
  found <- var_name %in% all_vars || any(grepl(var_name, all_vars))
  if(found && !var_name %in% all_vars) {
    # Find actual name
    idx <- grep(var_name, all_vars)[1]
    actual <- names(nhanes_clean)[idx]
    return(list(found=TRUE, actual=actual))
  }
  return(list(found=found, actual=ifelse(found, var_name, NA)))
}

################################################################################
# PAPER 1: BMI/Waist → Uric Acid (Chen PLOS ONE 2024)
################################################################################

cat('========================================================================\n')
cat('PAPER 1: BMI/Waist → Uric Acid (Chen PLOS ONE 2024, NHANES 2007-2018)\n')
cat('========================================================================\n')
cat('Their covariates (from paper):\n')
cat('  Demographics: age, sex, race, education, marital, PIR\n')
cat('  Anthropometric: BMI, waist\n')
cat('  Labs: eGFR, TG, creatinine, glucose, TC, LDL, HDL, HbA1c\n')
cat('  Clinical: SBP, DBP, sedentary, PA, HTN, diabetes\n')
cat('  Behavioral: smoking, alcohol, arthritis\n\n')

paper1_core <- list(
  outcome = 'lbxsua',
  exposure = 'bmi or bmxwaist',
  demographics = c('age', 'female', 'race1', 'education', 'dmdmartl', 'pir'),
  labs = c('egfr', 'lbxtr', 'lbxscr', 'lbxtc', 'lbdldl', 'lbdhdd', 'lbxgh'),
  clinical = c('bpxsy1', 'bpxdi1', 'hypertension', 'diabetes'),
  behavioral = c('smokestatus', 'alcoholstatus')
)

cat('Availability Check:\n')
for(category in names(paper1_core)) {
  if(category == 'outcome' || category == 'exposure') next
  cat('\n', toupper(category), ':\n', sep='')
  for(var in paper1_core[[category]]) {
    result <- check_var(var)
    cat(sprintf('  %-20s: %s\n', var, ifelse(result$found, '✓', '✗')))
  }
}

################################################################################
# PAPER 2: OBS → eGFR (Wu Heliyon 2024)
################################################################################

cat('\n========================================================================\n')
cat('PAPER 2: Oxidative Balance Score → eGFR (Wu Heliyon 2024, 2007-2018)\n')
cat('========================================================================\n')
cat('Model 1: age, sex, race, education, PIR, marital\n')
cat('Model 2: Model 1 + diabetes, HTN, CVD\n\n')

paper2_vars <- c('age', 'female', 'race1', 'education', 'pir', 'dmdmartl',
                 'diabetes', 'hypertension', 'chd', 'heartattack', 'stroke', 'egfr')

cat('Availability:\n')
for(var in paper2_vars) {
  result <- check_var(var)
  cat(sprintf('  %-20s: %s\n', var, ifelse(result$found, '✓', '✗')))
}

################################################################################
# PAPER 3: Birth Weight → SBP (Huang 2022, youth)
################################################################################

cat('\n========================================================================\n')
cat('PAPER 3: Birth Weight → SBP (Huang 2022, youth 8-15y, 2007-2018)\n')
cat('========================================================================\n')
cat('Note: This is YOUTH (8-15y) - may not match our adult analyses\n')
cat('Covariates: sex, age, race, PIR, height, weight, BMI, waist,\n')
cat('  TG, TC, LDL, glucose, uric acid, creatinine, BUN, HbA1c, mother age\n\n')

paper3_vars <- c('age', 'female', 'race1', 'pir', 'bmxht', 'bmxwt', 'bmi',
                 'bmxwaist', 'lbxtr', 'lbxtc', 'lbdldl', 'lbxsua', 'lbxscr',
                 'lbxsbu', 'lbxgh', 'bpxsy1')

cat('Availability:\n')
for(var in paper3_vars) {
  result <- check_var(var)
  cat(sprintf('  %-20s: %s\n', var, ifelse(result$found, '✓', '✗')))
}

cat('\n⚠️  Note: Birth weight likely NOT in our dataset (maternal/birth data)\n')
cat('Alternative: Can use similar SBP analysis with adult exposures\n')

################################################################################
# PAPER 4: Vitamin C → Uric Acid (Yang PLOS 2023)
################################################################################

cat('\n========================================================================\n')
cat('PAPER 4: Vitamin C → Uric Acid (Yang PLOS ONE 2023, 2011-2016)\n')
cat('========================================================================\n')
cat('Covariates: age, race, BMI, education, marital, creatinine, cholesterol,\n')
cat('  TG, HTN, diabetes, energy, protein, sugars, fiber, vit B6, folate,\n')
cat('  smoking, alcohol, PA\n\n')

paper4_vars <- c('age', 'female', 'race1', 'bmi', 'education', 'dmdmartl',
                 'lbxscr', 'lbxtc', 'lbxtr', 'hypertension', 'diabetes',
                 'dr1tkcal', 'dr1tprot', 'dr1tsugr', 'dr1tfibe', 'dr1tvb6',
                 'dr1tfola', 'smokestatus', 'alcoholstatus', 'mvpa_week')

cat('Availability:\n')
for(var in paper4_vars) {
  result <- check_var(var)
  cat(sprintf('  %-20s: %s\n', var, ifelse(result$found, '✓', '✗')))
}

cat('\n========================================================================\n')
cat('                    FEASIBILITY SUMMARY\n')
cat('========================================================================\n')

cat('\nPAPER 1 (BMI/Waist → Uric Acid): ✅ HIGHLY FEASIBLE\n')
cat('  - Have nearly all covariates\n')
cat('  - Can use subset matching their model\n')

cat('\nPAPER 2 (OBS → eGFR): ⚠️  PARTIAL\n')
cat('  - Have demographics and health conditions\n')
cat('  - Need to construct OBS from dietary/nutrient components\n')

cat('\nPAPER 3 (Birth Weight → SBP): ❌ NOT FEASIBLE\n')
cat('  - Missing birth weight (maternal data)\n')
cat('  - Alternative: Use obesity→SBP in adults\n')

cat('\nPAPER 4 (Vitamin C → Uric Acid): ✅ FEASIBLE\n')
cat('  - Have most covariates\n')
cat('  - Have dietary recall variables\n')

cat('\n========================================================================\n')




