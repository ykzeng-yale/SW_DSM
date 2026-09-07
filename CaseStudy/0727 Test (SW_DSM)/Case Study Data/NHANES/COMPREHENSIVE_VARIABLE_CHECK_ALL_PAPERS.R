################################################################################
# COMPREHENSIVE VARIABLE CHECK: ALL 12 UNWEIGHTED PSM PAPERS
# Determine exact feasibility for each paper
################################################################################

rm(list = ls())
options(scipen = 999)

library(dplyr)
library(haven)

load("data/nhanes_2007_2018.rda")

# Convert labelled
nhanes_clean <- nhanes_2007_2018 %>%
  mutate(across(where(is.labelled), as.numeric))

cat("\n")
cat("==============================================================================\n")
cat("   COMPREHENSIVE FEASIBILITY CHECK: ALL 12 PAPERS\n")
cat("==============================================================================\n")

all_vars <- tolower(names(nhanes_clean))

check_feasibility <- function(paper_name, exposure_vars, outcome_vars, 
                              confounders, note = "") {
  cat("\n========================================================================\n")
  cat(" ", paper_name, "\n")
  cat("========================================================================\n")
  
  if(note != "") cat("Note:", note, "\n")
  
  # Check exposure
  cat("\n--- Exposure Variables ---\n")
  exposure_found <- FALSE
  for(var in exposure_vars) {
    found <- var %in% all_vars || any(grepl(var, all_vars))
    cat(sprintf("  %-30s: %s\n", var, ifelse(found, "✓", "✗")))
    if(found) exposure_found <- TRUE
  }
  
  # Check outcome
  cat("\n--- Outcome Variables ---\n")
  outcome_found <- FALSE
  for(var in outcome_vars) {
    found <- var %in% all_vars || any(grepl(var, all_vars))
    cat(sprintf("  %-30s: %s\n", var, ifelse(found, "✓", "✗")))
    if(found) outcome_found <- TRUE
  }
  
  # Check confounders
  cat("\n--- Key Confounders ---\n")
  conf_count <- 0
  for(var in confounders) {
    found <- var %in% all_vars || any(grepl(var, all_vars))
    if(found) conf_count <- conf_count + 1
  }
  cat(sprintf("  Available: %d of %d\n", conf_count, length(confounders)))
  
  # Overall feasibility
  feasible <- exposure_found && outcome_found && (conf_count >= length(confounders)*0.7)
  
  cat("\n📊 FEASIBILITY:", ifelse(feasible, "✅ YES", "❌ NO"), "\n")
  
  return(list(feasible = feasible, exposure = exposure_found, 
              outcome = outcome_found, confounders = conf_count))
}

################################################################################
# PAPER-BY-PAPER CHECK
################################################################################

results <- list()

# Paper 1: Blood Transfusion → Mortality
results$paper1 <- check_feasibility(
  "PAPER 1: Blood Transfusion → Mortality (Shi 2024)",
  exposure_vars = c("transfusion", "blood.*trans", "bpq"),
  outcome_vars = c("mortstat", "cvamort", "permth"),
  confounders = c("age", "female", "race1", "education", "pir", 
                  "hypertension", "diabetes", "cancer")
)

# Paper 2: LE8 → Mortality in CKD
results$paper2 <- check_feasibility(
  "PAPER 2: Life's Essential 8 → Mortality in CKD (Han 2024)",
  exposure_vars = c("le8", "mvpa", "smoke", "sleep", "bmi", "hdl", "bp"),
  outcome_vars = c("mortstat", "permth"),
  confounders = c("age", "female", "race1", "education", "pir"),
  note = "Need to construct LE8 score from components"
)

# Paper 3: MVPA → Mortality (DONE)
results$paper3 <- check_feasibility(
  "PAPER 3: MVPA → Mortality (Yao 2025) ✅ DONE",
  exposure_vars = c("mvpa_week", "mvpa_cat"),
  outcome_vars = c("mortstat", "permth"),
  confounders = c("age", "female", "race1", "education", "pir", "bmi")
)

# Paper 4: SII → Steatosis  
results$paper4 <- check_feasibility(
  "PAPER 4: SII → Hepatic Steatosis (Song 2022)",
  exposure_vars = c("neutrophil", "lymphocyte", "platelet", "lbxne", "lbxly", "lbxplt"),
  outcome_vars = c("steatosis", "liver", "lbxsal", "lbxsas", "fibroscan"),
  confounders = c("age", "female", "race1", "bmi", "diabetes"),
  note = "SII = (Neutrophil × Platelet) / Lymphocyte"
)

# Paper 5: SII → DKD
results$paper5 <- check_feasibility(
  "PAPER 5: SII → Diabetic Kidney Disease (Guo 2022)",
  exposure_vars = c("neutrophil", "lymphocyte", "platelet", "lbxne", "lbxly"),
  outcome_vars = c("dkd", "kidney", "albumin", "acr", "egfr"),
  confounders = c("age", "female", "race1", "bmi", "diabetes"),
  note = "Requires DKD definition + SII"
)

# Paper 6: GNRI → Osteoarthritis
results$paper6 <- check_feasibility(
  "PAPER 6: GNRI → Osteoarthritis (Lu 2025)",
  exposure_vars = c("gnri", "albumin", "weight", "height"),
  outcome_vars = c("arthritis", "mcq", "joint"),
  confounders = c("age", "female", "race1", "pir", "bmi"),
  note = "GNRI = (1.489 × albumin) + (41.7 × weight/ideal_weight)"
)

# Paper 7: MMA → Mortality
results$paper7 <- check_feasibility(
  "PAPER 7: Methylmalonic Acid → Mortality (Wang 2021)",
  exposure_vars = c("mma", "methylmalonic", "lbxmma"),
  outcome_vars = c("mortstat", "permth", "diabetes"),
  confounders = c("age", "female", "race1", "education", "bmi"),
  note = "In diabetes subset"
)

# Paper 8: MAFLD → Mortality
results$paper8 <- check_feasibility(
  "PAPER 8: MAFLD → Mortality (Deng 2021)",
  exposure_vars = c("mafld", "fatty liver", "lbxsal", "lbxsas", "ultrasound"),
  outcome_vars = c("mortstat", "permth"),
  confounders = c("age", "female", "race1", "bmi", "diabetes"),
  note = "Metabolic-associated fatty liver disease"
)

# Paper 9: Retinopathy → Mortality
results$paper9 <- check_feasibility(
  "PAPER 9: Diabetic Retinopathy → Mortality (Gui 2023)",
  exposure_vars = c("retinopathy", "opx", "fundus", "eye"),
  outcome_vars = c("mortstat", "permth", "diabetes"),
  confounders = c("age", "female", "race1", "education", "diabetes"),
  note = "Requires 2005-2008 ophthalmology exam - NOT in 2007-2018"
)

# Paper 10: PPIs → Kidney Stones
results$paper10 <- check_feasibility(
  "PAPER 10: PPIs → Kidney Stones (Zhang 2025)",
  exposure_vars = c("ppi", "proton pump", "medication", "rxd"),
  outcome_vars = c("kidney stone", "kiq", "urinary"),
  confounders = c("age", "female", "race1", "bmi", "diabetes"),
  note = "PPI use from prescription data"
)

# Paper 11: Visceral Fat → Hyperuricemia
results$paper11 <- check_feasibility(
  "PAPER 11: Visceral Fat → Hyperuricemia (Xie 2025)",
  exposure_vars = c("visceral fat", "waist", "bmxwaist", "dxa"),
  outcome_vars = c("uric acid", "lbxsua", "gout", "hyperuricemia"),
  confounders = c("age", "female", "race1", "bmi", "hypertension"),
  note = "Visceral fat metabolism score"
)

# Paper 12: OAB → Mortality
results$paper12 <- check_feasibility(
  "PAPER 12: Overactive Bladder → Mortality (Mao 2025)",
  exposure_vars = c("overactive bladder", "oab", "urinary", "incontinence", "kiq"),
  outcome_vars = c("mortstat", "permth"),
  confounders = c("age", "female", "race1", "bmi", "diabetes"),
  note = "OAB definition from questionnaire"
)

################################################################################
# SUMMARY
################################################################################

cat("\n")
cat("==============================================================================\n")
cat("                    FEASIBILITY SUMMARY\n")
cat("==============================================================================\n")

feasible_papers <- sapply(results, function(x) x$feasible)
cat("\nFeasible papers:", sum(feasible_papers), "of", length(results), "\n")

cat("\n--- FEASIBILITY BY PAPER ---\n")
for(i in seq_along(results)) {
  status <- ifelse(results[[i]]$feasible, "✅ FEASIBLE", "❌ NOT FEASIBLE")
  cat(sprintf("Paper %2d: %s\n", i, status))
}

# Save
save(results, file = "analysis_results/all_papers_feasibility.rda")

cat("\n==============================================================================\n")
cat("Feasibility check complete\n")
cat("Results saved to: analysis_results/all_papers_feasibility.rda\n")
cat("==============================================================================\n")
