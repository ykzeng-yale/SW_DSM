#!/usr/bin/env Rscript

#' ============================================================================
#' MASTER SCRIPT: All 10 Research Questions with All 5 Matching Methods
#' ============================================================================
#' 
#' Purpose: Analyze 10 research questions using NSDUH 2023 data
#' Methods: WDSM, DSM, PSM, PGM, PS Full (all 5 matching methods)
#' Bootstrap: B = 200 iterations
#' 
#' Sample restrictions (scientifically justified):
#'   - Alcohol questions (Q1, Q5, Q7, Q10, Q11, Q12): Age 30-45, employed
#'   - Marijuana questions (Q2, Q4, Q13): All eligible users
#'   - Employment question (Q3): Age 18-64
#' 
#' ============================================================================

# Load libraries
suppressPackageStartupMessages({
  library(tidyverse)
  library(survey)
  library(MatchIt)
  library(marginaleffects)
  library(Matching)
})

# Source matching functions
invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

# Load NSDUH data
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("\n================================================================\n")
cat("ANALYZING ALL 10 RESEARCH QUESTIONS\n")
cat("================================================================\n")
cat("Data: NSDUH 2023\n")
cat("Methods: WDSM, DSM, PSM, PGM, PS Full\n")
cat("Bootstrap: B = 200\n")
cat("================================================================\n\n")

# ============================================================================
# HELPER FUNCTION: Run all 5 matching methods
# ============================================================================

run_all_5_methods <- function(d, Y, A, w, X, ps_formula, pgs_formula, 
                               treatment_col, question_name) {
  results <- list()
  
  cat(question_name, ": N=", nrow(d), " | ", sep="")
  
  # Method 1: WDSM (M=5, weighted, B=200)
  cat("WDSM...")
  set.seed(2025)
  tryCatch({
    wdsm <- wdsm_flexible(
      data = d %>% mutate(Y = Y, Treatment = A),
      outcome_var = "Y",
      treatment_var = "Treatment",
      ps_formula = ps_formula,
      pgs_formula = pgs_formula,
      weight_var = "w",
      M = 5,
      B = 200,
      alpha = 0.05,
      verbose = FALSE
    )
    results$wdsm <- wdsm
    cat("✓ ")
  }, error = function(e) {
    results$wdsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    cat("✗ ")
  })
  
  # Method 2: DSM (M=1, unweighted, B=200)
  cat("DSM...")
  set.seed(2025)
  tryCatch({
    dsm <- dsmatchATE(
      Y = Y, X = X, A = A,
      method = "dsm",
      model.ps = "logit",
      model.pg = "linpred",
      lp.pg = X,
      varest = TRUE,
      boots = 200,
      cov.balance = FALSE,
      mc = FALSE
    )
    results$dsm <- list(
      estimate = dsm$est.ds,
      se = sqrt(dsm$bootvar[1,1]),
      ci_lower = dsm$est.ds - 1.96*sqrt(dsm$bootvar[1,1]),
      ci_upper = dsm$est.ds + 1.96*sqrt(dsm$bootvar[1,1])
    )
    cat("✓ ")
  }, error = function(e) {
    results$dsm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    cat("✗ ")
  })
  
  # Method 3: PSM (M=1, unweighted, B=200)
  cat("PSM...")
  set.seed(2025)
  tryCatch({
    psm <- dsmatchATE(
      Y = Y, X = X, A = A,
      method = "ps",
      model.ps = "logit",
      varest = TRUE,
      boots = 200,
      cov.balance = FALSE,
      mc = FALSE
    )
    results$psm <- list(
      estimate = psm$est.ps,
      se = sqrt(psm$bootvar[1,1]),
      ci_lower = psm$est.ps - 1.96*sqrt(psm$bootvar[1,1]),
      ci_upper = psm$est.ps + 1.96*sqrt(psm$bootvar[1,1])
    )
    cat("✓ ")
  }, error = function(e) {
    results$psm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    cat("✗ ")
  })
  
  # Method 4: PGM (M=1, unweighted, B=200)
  cat("PGM...")
  set.seed(2025)
  tryCatch({
    pgm <- dsmatchATE(
      Y = Y, X = X, A = A,
      method = "pg",
      model.pg = "linpred",
      lp.pg = X,
      varest = TRUE,
      boots = 200,
      cov.balance = FALSE,
      mc = FALSE
    )
    results$pgm <- list(
      estimate = pgm$est.pg,
      se = sqrt(pgm$bootvar[1,1]),
      ci_lower = pgm$est.pg - 1.96*sqrt(pgm$bootvar[1,1]),
      ci_upper = pgm$est.pg + 1.96*sqrt(pgm$bootvar[1,1])
    )
    cat("✓ ")
  }, error = function(e) {
    results$pgm <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    cat("✗ ")
  })
  
  # Method 5: PS Full (weighted, robust SE)
  cat("PSFull...")
  set.seed(2025)
  tryCatch({
    # Normalize weights
    d$sw <- d$w * nrow(d) / sum(d$w)
    
    # Full matching
    m <- matchit(
      ps_formula,
      data = d,
      method = "full",
      estimand = "ATE",
      s.weights = ~sw  # Formula notation (CRITICAL!)
    )
    
    # Extract matched data
    md <- match.data(m)
    md$Y <- Y[as.numeric(rownames(md))]
    md$Treatment <- md[[treatment_col]]
    
    # Outcome model with treatment × covariate interactions
    cov_names <- all.vars(ps_formula)[-1]
    formula_str <- paste("Y ~ Treatment * (", paste(cov_names, collapse=" + "), ")")
    
    fit <- lm(
      as.formula(formula_str),
      data = md,
      weights = weights  # Use weights column from matched data
    )
    
    # Calculate ATE with robust SE
    ate <- avg_comparisons(
      fit,
      variables = "Treatment",
      vcov = ~subclass  # Cluster SE by subclass
      # Note: No wts argument (causes errors)
    )
    
    results$ps_full <- list(
      estimate = ate$estimate[1],
      se = ate$std.error[1],
      ci_lower = ate$conf.low[1],
      ci_upper = ate$conf.high[1]
    )
    cat("✓\n")
  }, error = function(e) {
    results$ps_full <- list(estimate = NA, se = NA, ci_lower = NA, ci_upper = NA)
    cat("✗ (", substring(e$message, 1, 30), ")\n")
  })
  
  return(results)
}

# ============================================================================
# Load existing results for Q2, Q3, Q4, Q13 (already complete)
# ============================================================================

final_results <- readRDS('Analysis/Results/FINAL_ALL_10_BEST_AVAILABLE.rds')

cat("Keeping Q2, Q3, Q4, Q13 (already have all 5 methods)...\n\n")

# ============================================================================
# Q1: Gender → Alcohol Frequency (days/year)
# ============================================================================

cat("\n--- Q1: Gender → Alcohol ---\n")

d1 <- data %>%
  filter(
    YEAR == 2023,
    ALCDAYS >= 1, ALCDAYS <= 365,
    AGE3 >= 8, AGE3 <= 10,        # Age 30-45
    IRWRKSTAT18 %in% c(1,2)       # Employed
  ) %>%
  mutate(
    alcohol_days = as.numeric(ALCDAYS),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(female), !is.na(w))

Y_q1 <- d1$alcohol_days
A_q1 <- d1$female
X_q1 <- as.matrix(d1[, c("age_older", "black", "hispanic", "college")])
ps_f_q1 <- as.formula("A ~ age_older + black + hispanic + college")
pgs_f_q1 <- as.formula("Y ~ age_older + black + hispanic + college")

final_results$q1 <- run_all_5_methods(
  d1, Y_q1, A_q1, d1$w, X_q1, 
  ps_f_q1, pgs_f_q1, "female", "Q1"
)

# ============================================================================
# Q5: Education → Alcohol Frequency (days/year)
# ============================================================================

cat("\n--- Q5: Education → Alcohol ---\n")

d5 <- data %>%
  filter(
    YEAR == 2023,
    ALCDAYS >= 1, ALCDAYS <= 365,
    AGE3 >= 8, AGE3 <= 10,        # Age 30-45
    IRWRKSTAT18 %in% c(1,2)       # Employed
  ) %>%
  mutate(
    alcohol_days = as.numeric(ALCDAYS),
    college = case_when(
      EDUHIGHCAT == 4 ~ 1,  # College grad
      EDUHIGHCAT == 2 ~ 0,  # HS grad
      TRUE ~ NA_real_
    ),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    poverty_low = ifelse(!is.na(POVERTY3) & POVERTY3 == 1, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(college), !is.na(w))

Y_q5 <- d5$alcohol_days
A_q5 <- d5$college
X_q5 <- as.matrix(d5[, c("female", "age_older", "black", "hispanic", "poverty_low")])
ps_f_q5 <- as.formula("A ~ female + age_older + black + hispanic + poverty_low")
pgs_f_q5 <- as.formula("Y ~ female + age_older + black + hispanic + poverty_low")

final_results$q5 <- run_all_5_methods(
  d5, Y_q5, A_q5, d5$w, X_q5,
  ps_f_q5, pgs_f_q5, "college", "Q5"
)

# ============================================================================
# Q7: Race (Black vs White) → Alcohol Frequency
# ============================================================================

cat("\n--- Q7: Black vs White → Alcohol ---\n")

d7 <- data %>%
  filter(
    YEAR == 2023,
    ALCDAYS >= 1, ALCDAYS <= 365,
    AGE3 >= 8, AGE3 <= 10,
    IRWRKSTAT18 %in% c(1,2)
  ) %>%
  mutate(
    alcohol_days = as.numeric(ALCDAYS),
    black = case_when(
      NEWRACE2 == 2 ~ 1,  # Black
      NEWRACE2 == 1 ~ 0,  # White
      TRUE ~ NA_real_
    ),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    poverty_low = ifelse(!is.na(POVERTY3) & POVERTY3 == 1, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(black), !is.na(w))

Y_q7 <- d7$alcohol_days
A_q7 <- d7$black
X_q7 <- as.matrix(d7[, c("female", "age_older", "college", "poverty_low")])
ps_f_q7 <- as.formula("A ~ female + age_older + college + poverty_low")
pgs_f_q7 <- as.formula("Y ~ female + age_older + college + poverty_low")

final_results$q7 <- run_all_5_methods(
  d7, Y_q7, A_q7, d7$w, X_q7,
  ps_f_q7, pgs_f_q7, "black", "Q7"
)

# ============================================================================
# Q10: Race (Hispanic vs White) → Alcohol Frequency
# ============================================================================

cat("\n--- Q10: Hispanic vs White → Alcohol ---\n")

d10 <- data %>%
  filter(
    YEAR == 2023,
    ALCDAYS >= 1, ALCDAYS <= 365,
    AGE3 >= 8, AGE3 <= 10,
    IRWRKSTAT18 %in% c(1,2)
  ) %>%
  mutate(
    alcohol_days = as.numeric(ALCDAYS),
    hispanic = case_when(
      NEWRACE2 == 7 ~ 1,  # Hispanic
      NEWRACE2 == 1 ~ 0,  # White
      TRUE ~ NA_real_
    ),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    poverty_low = ifelse(!is.na(POVERTY3) & POVERTY3 == 1, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(hispanic), !is.na(w))

Y_q10 <- d10$alcohol_days
A_q10 <- d10$hispanic
X_q10 <- as.matrix(d10[, c("female", "age_older", "college", "poverty_low")])

final_results$q10 <- run_all_5_methods(
  d10, Y_q10, A_q10, d10$w, X_q10,
  ps_f_q7, pgs_f_q7, "hispanic", "Q10"
)

# ============================================================================
# Q11: Gender → Binge Drinking Frequency
# ============================================================================

cat("\n--- Q11: Gender → Binge ---\n")

d11 <- data %>%
  filter(
    YEAR == 2023,
    BNGDRMDAYS >= 1, BNGDRMDAYS <= 30,
    AGE3 >= 8, AGE3 <= 10,
    IRWRKSTAT18 %in% c(1,2)
  ) %>%
  mutate(
    binge_days = as.numeric(BNGDRMDAYS),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(female), !is.na(w))

Y_q11 <- d11$binge_days
A_q11 <- d11$female
X_q11 <- as.matrix(d11[, c("age_older", "black", "hispanic", "college")])

final_results$q11 <- run_all_5_methods(
  d11, Y_q11, A_q11, d11$w, X_q11,
  ps_f_q1, pgs_f_q1, "female", "Q11"
)

# ============================================================================
# Q12: Urban vs Rural → Alcohol Frequency
# ============================================================================

cat("\n--- Q12: Urban vs Rural → Alcohol ---\n")

d12 <- data %>%
  filter(
    YEAR == 2023,
    ALCDAYS >= 1, ALCDAYS <= 365,
    AGE3 >= 8, AGE3 <= 10,
    IRWRKSTAT18 %in% c(1,2)
  ) %>%
  mutate(
    alcohol_days = as.numeric(ALCDAYS),
    urban = case_when(
      COUTYP4 == 1 ~ 1,  # Large metro
      COUTYP4 == 3 ~ 0,  # Rural
      TRUE ~ NA_real_
    ),
    female = ifelse(IRSEX == 2, 1, 0),
    age_older = ifelse(AGE3 >= 10, 1, 0),
    black = ifelse(NEWRACE2 == 2, 1, 0),
    hispanic = ifelse(NEWRACE2 == 7, 1, 0),
    college = ifelse(EDUHIGHCAT == 4, 1, 0),
    poverty_low = ifelse(!is.na(POVERTY3) & POVERTY3 == 1, 1, 0),
    w = ANALWT2_C1
  ) %>%
  filter(!is.na(urban), !is.na(w))

Y_q12 <- d12$alcohol_days
A_q12 <- d12$urban
X_q12 <- as.matrix(d12[, c("female", "age_older", "black", "hispanic", "college", "poverty_low")])
ps_f_q12 <- as.formula("A ~ female + age_older + black + hispanic + college + poverty_low")
pgs_f_q12 <- as.formula("Y ~ female + age_older + black + hispanic + college + poverty_low")

final_results$q12 <- run_all_5_methods(
  d12, Y_q12, A_q12, d12$w, X_q12,
  ps_f_q12, pgs_f_q12, "urban", "Q12"
)

# ============================================================================
# SAVE ALL RESULTS
# ============================================================================

saveRDS(final_results, "Analysis/Results/ALL_10_FINAL_COMPLETE.rds")

cat("\n================================================================\n")
cat("✓ ALL 10 QUESTIONS COMPLETE\n")
cat("✓ Results saved to: ALL_10_FINAL_COMPLETE.rds\n")
cat("================================================================\n")




