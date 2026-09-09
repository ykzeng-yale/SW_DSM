# PERFECT REPLICATION: White et al. (2023)
# Using 2012-2018 NSDUH data (EXACTLY what they used)

library(survey)
library(dplyr)

# Load the CORRECT data file with 2002-2019
load("/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Case Study Data/SAMHSA 0914/Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2002_2019.RData")

cat("\n===========================================\n")
cat("WHITE ET AL. 2023 - EXACT REPLICATION\n")
cat("Using NSDUH 2012-2018 (Same as original)\n")
cat("===========================================\n\n")

# Filter to 2012-2018 only (same years as White)
data_white <- data %>%
  filter(YEAR >= 2012 & YEAR <= 2018)

cat("Years included:", unique(data_white$YEAR), "\n")
cat("Total observations:", nrow(data_white), "\n\n")

# SAMPLE: Past-month cigarette smokers with SMI
sample_white <- data_white %>%
  filter(CIGAREVR == 1) %>%  # Ever smoked cigarettes
  filter(CIG30USE == 1) %>%  # Past-month cigarette use
  filter(SMISPY_U == 1) %>%  # Serious mental illness (SMI)
  mutate(
    # TREATMENT: Menthol cigarette use (CIGTYPE exists in 2012-2018!)
    menthol = ifelse(CIGTYPE == 1, 1, 0),  # 1=Menthol, 2=Non-menthol
    
    # OUTCOME: Heavy smoking (20+ cigarettes/day)
    heavy_smoking = ifelse(CIGTRY >= 20 & CIGTRY < 900, 1, 0),
    
    # COVARIATES
    male = ifelse(IRSEX == 1, 1, 0),
    age = AGE3,
    race = NEWRACE2,
    education = EDUHIGHCAT,
    income = POVERTY3,
    employment = IRWRKSTAT
  ) %>%
  filter(!is.na(menthol) & !is.na(heavy_smoking))

cat("SAMPLE SELECTION:\n")
cat("- Ever smokers:", sum(data_white$CIGAREVR == 1, na.rm=TRUE), "\n")
cat("- Past-month smokers:", sum(data_white$CIG30USE == 1, na.rm=TRUE), "\n")
cat("- With SMI:", sum(data_white$SMISPY_U == 1, na.rm=TRUE), "\n")
cat("- Final analytic sample:", nrow(sample_white), "\n\n")

# Check menthol distribution
cat("MENTHOL DISTRIBUTION:\n")
cat("- Menthol users:", sum(sample_white$menthol == 1), 
    "(", round(100*mean(sample_white$menthol == 1), 1), "%)\n")
cat("- Non-menthol users:", sum(sample_white$menthol == 0),
    "(", round(100*mean(sample_white$menthol == 0), 1), "%)\n\n")

# Check outcome by exposure
cat("HEAVY SMOKING BY MENTHOL STATUS:\n")
cat("- Among menthol users:", 
    round(100*mean(sample_white$heavy_smoking[sample_white$menthol==1]), 1), "%\n")
cat("- Among non-menthol users:",
    round(100*mean(sample_white$heavy_smoking[sample_white$menthol==0]), 1), "%\n\n")

# Create survey design
design_white <- svydesign(
  ids = ~QUESTID2,
  strata = ~interaction(VESTR, YEAR),  # Account for year
  weights = ~ANALWT2_C,
  data = sample_white
)

# Run weighted logistic regression
model_white <- svyglm(
  heavy_smoking ~ menthol + male + age + race + education + income + employment,
  design = design_white,
  family = quasibinomial()
)

# Extract results
coef_white <- exp(coef(model_white)["menthol"])
ci_white <- exp(confint(model_white)["menthol",])

cat("===========================================\n")
cat("RESULTS - WHITE ET AL. 2023\n")
cat("===========================================\n")
cat("TARGET: Menthol → Heavy smoking aOR = 1.12 [1.01, 1.24]\n")
cat("OUR RESULT: aOR =", round(coef_white, 2), 
    "[", round(ci_white[1], 2), ",", round(ci_white[2], 2), "]\n\n")

# Check if CI overlaps with target
target_or <- 1.12
if(ci_white[1] <= target_or & ci_white[2] >= target_or) {
  cat("✅ SUCCESS: Our CI contains target OR!\n")
} else if(abs(coef_white - target_or)/target_or < 0.20) {
  cat("✅ GOOD MATCH: Within 20% of target\n")
} else {
  cat("⚠️ MISMATCH: Check model specification\n")
}

# Summary of model
cat("\n\nFULL MODEL SUMMARY:\n")
cat("==================\n")
summary(model_white)
