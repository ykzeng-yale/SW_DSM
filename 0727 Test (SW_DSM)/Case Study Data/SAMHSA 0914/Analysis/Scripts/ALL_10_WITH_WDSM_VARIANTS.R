#!/usr/bin/env Rscript

#' ============================================================================
#' ALL 10 QUESTIONS WITH WDSM M=1, M=3, M=5 VARIANTS
#' ============================================================================
#' 
#' Methods: 7 total per question
#'   - WDSM (M=1, weighted)
#'   - WDSM (M=3, weighted)
#'   - WDSM (M=5, weighted)
#'   - DSM (M=1, unweighted)
#'   - PSM (M=1, unweighted)
#'   - PGM (M=1, unweighted)
#'   - PS Full (weighted)
#' 
#' Bootstrap: B=200 for all
#' ============================================================================

suppressPackageStartupMessages({
  library(tidyverse); library(survey); library(MatchIt)
  library(marginaleffects); library(Matching)
})

invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("\n================================================================\n")
cat("ALL 10 QUESTIONS WITH WDSM M=1, M=3, M=5\n")
cat("================================================================\n\n")

# ============================================================================
# ENHANCED HELPER FUNCTION: Run all 7 variants
# ============================================================================

run_all_7 <- function(d, Y, A, w, X, ps_f, pgs_f, tcol, qname) {
  r <- list()
  cat(qname, ": N=", nrow(d), "\n  ", sep="")
  
  # WDSM M=1
  cat("WDSM(M=1)...")
  set.seed(2025)
  tryCatch({
    wdsm1 <- wdsm_flexible(d %>% mutate(Y=Y, Treatment=A), "Y", "Treatment", 
                           ps_f, pgs_f, "w", M=1, B=200, verbose=FALSE)
    r$wdsm_m1 <- wdsm1
    cat("✓ ")
  }, error=function(e) {
    r$wdsm_m1 <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
    cat("✗ ")
  })
  
  # WDSM M=3
  cat("WDSM(M=3)...")
  set.seed(2025)
  tryCatch({
    wdsm3 <- wdsm_flexible(d %>% mutate(Y=Y, Treatment=A), "Y", "Treatment",
                           ps_f, pgs_f, "w", M=3, B=200, verbose=FALSE)
    r$wdsm_m3 <- wdsm3
    cat("✓ ")
  }, error=function(e) {
    r$wdsm_m3 <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
    cat("✗ ")
  })
  
  # WDSM M=5
  cat("WDSM(M=5)...")
  set.seed(2025)
  tryCatch({
    wdsm5 <- wdsm_flexible(d %>% mutate(Y=Y, Treatment=A), "Y", "Treatment",
                           ps_f, pgs_f, "w", M=5, B=200, verbose=FALSE)
    r$wdsm_m5 <- wdsm5
    cat("✓ ")
  }, error=function(e) {
    r$wdsm_m5 <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
    cat("✗ ")
  })
  
  # DSM
  cat("DSM...")
  set.seed(2025)
  tryCatch({
    dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred",
                      lp.pg=X, varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
    r$dsm <- list(estimate=dsm$est.ds, se=sqrt(dsm$bootvar[1,1]),
                  ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]),
                  ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]))
    cat("✓ ")
  }, error=function(e) {
    r$dsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
    cat("✗ ")
  })
  
  # PSM
  cat("PSM...")
  set.seed(2025)
  tryCatch({
    psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit",
                      varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
    r$psm <- list(estimate=psm$est.ps, se=sqrt(psm$bootvar[1,1]),
                  ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]),
                  ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]))
    cat("✓ ")
  }, error=function(e) {
    r$psm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
    cat("✗ ")
  })
  
  # PGM
  cat("PGM...")
  set.seed(2025)
  tryCatch({
    pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", lp.pg=X,
                      varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
    r$pgm <- list(estimate=pgm$est.pg, se=sqrt(pgm$bootvar[1,1]),
                  ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]),
                  ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]))
    cat("✓ ")
  }, error=function(e) {
    r$pgm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
    cat("✗ ")
  })
  
  # PS Full
  cat("PSFull...")
  set.seed(2025)
  tryCatch({
    d$sw <- d$w * nrow(d) / sum(d$w)
    m <- matchit(ps_f, data=d, method="full", estimand="ATE", s.weights=~sw)
    md <- match.data(m)
    md$Y <- Y[as.numeric(rownames(md))]
    md$Treatment <- md[[tcol]]
    cvn <- all.vars(ps_f)[-1]
    fs <- paste("Y ~ Treatment * (", paste(cvn, collapse=" + "), ")")
    fit <- lm(as.formula(fs), data=md, weights=weights)
    ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass)
    r$ps_full <- list(estimate=ate$estimate[1], se=ate$std.error[1],
                      ci_lower=ate$conf.low[1], ci_upper=ate$conf.high[1])
    cat("✓\n")
  }, error=function(e) {
    r$ps_full <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA)
    cat("✗\n")
  })
  
  return(r)
}

# ============================================================================
# RUN ALL 10 QUESTIONS
# ============================================================================

all_results <- list()

# Q1: Gender → Alcohol (employed, age 30-45)
cat("\n")
d <- data %>% filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, AGE3>=8, AGE3<=10, IRWRKSTAT18 %in% c(1,2)) %>%
  mutate(alcohol_days=as.numeric(ALCDAYS), female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0),
         black=ifelse(NEWRACE2==2,1,0), hispanic=ifelse(NEWRACE2==7,1,0), college=ifelse(EDUHIGHCAT==4,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(female), !is.na(w))
Y <- d$alcohol_days; A <- d$female; X <- as.matrix(d[,c("age_older","black","hispanic","college")])
ps_f <- as.formula("A ~ age_older + black + hispanic + college")
pgs_f <- as.formula("Y ~ age_older + black + hispanic + college")
all_results$q1 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "female", "Q1")

# Q2: Gender → Marijuana (all users)
cat("\n")
d <- data %>% filter(YEAR==2023, MJDAY30A>=1, MJDAY30A<=30) %>%
  mutate(marijuana_days=as.numeric(MJDAY30A), female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0),
         black=ifelse(NEWRACE2==2,1,0), hispanic=ifelse(NEWRACE2==7,1,0), college=ifelse(EDUHIGHCAT==4,1,0),
         unemployed=ifelse(IRWRKSTAT18==3,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(female), !is.na(w))
Y <- d$marijuana_days; A <- d$female; X <- as.matrix(d[,c("age_older","black","hispanic","college","unemployed")])
ps_f <- as.formula("A ~ age_older + black + hispanic + college + unemployed")
pgs_f <- as.formula("Y ~ age_older + black + hispanic + college + unemployed")
all_results$q2 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "female", "Q2")

# Q3: Employment → Alcohol (age 18-64)
cat("\n")
d <- data %>% filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, CATAGE>=2, CATAGE<=5) %>%
  mutate(alcohol_days=as.numeric(ALCDAYS), unemployed=case_when(IRWRKSTAT18==3~1, IRWRKSTAT18==1~0, TRUE~NA_real_),
         female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0), black=ifelse(NEWRACE2==2,1,0),
         hispanic=ifelse(NEWRACE2==7,1,0), college=ifelse(EDUHIGHCAT==4,1,0),
         poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(unemployed), !is.na(w))
Y <- d$alcohol_days; A <- d$unemployed; X <- as.matrix(d[,c("female","age_older","black","hispanic","college","poverty_low")])
ps_f <- as.formula("A ~ female + age_older + black + hispanic + college + poverty_low")
pgs_f <- as.formula("Y ~ female + age_older + black + hispanic + college + poverty_low")
all_results$q3 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "unemployed", "Q3")

# Q4: Age → Marijuana (all users)
cat("\n")
d <- data %>% filter(YEAR==2023, MJDAY30A>=1, MJDAY30A<=30) %>%
  mutate(marijuana_days=as.numeric(MJDAY30A), young=case_when(CATAGE==2~1, CATAGE>=3~0, TRUE~NA_real_),
         female=ifelse(IRSEX==2,1,0), black=ifelse(NEWRACE2==2,1,0), hispanic=ifelse(NEWRACE2==7,1,0),
         college=ifelse(EDUHIGHCAT==4,1,0), unemployed=ifelse(IRWRKSTAT18==3,1,0),
         poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(young), !is.na(w))
Y <- d$marijuana_days; A <- d$young; X <- as.matrix(d[,c("female","black","hispanic","college","unemployed","poverty_low")])
ps_f <- as.formula("A ~ female + black + hispanic + college + unemployed + poverty_low")
pgs_f <- as.formula("Y ~ female + black + hispanic + college + unemployed + poverty_low")
all_results$q4 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "young", "Q4")

# Q5: Education → Alcohol (employed, age 30-45)
cat("\n")
d <- data %>% filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, AGE3>=8, AGE3<=10, IRWRKSTAT18 %in% c(1,2)) %>%
  mutate(alcohol_days=as.numeric(ALCDAYS), college=case_when(EDUHIGHCAT==4~1, EDUHIGHCAT==2~0, TRUE~NA_real_),
         female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0), black=ifelse(NEWRACE2==2,1,0),
         hispanic=ifelse(NEWRACE2==7,1,0), poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(college), !is.na(w))
Y <- d$alcohol_days; A <- d$college; X <- as.matrix(d[,c("female","age_older","black","hispanic","poverty_low")])
ps_f <- as.formula("A ~ female + age_older + black + hispanic + poverty_low")
pgs_f <- as.formula("Y ~ female + age_older + black + hispanic + poverty_low")
all_results$q5 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "college", "Q5")

# Q7: Black vs White → Alcohol (employed, age 30-45)
cat("\n")
d <- data %>% filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, AGE3>=8, AGE3<=10, IRWRKSTAT18 %in% c(1,2)) %>%
  mutate(alcohol_days=as.numeric(ALCDAYS), black=case_when(NEWRACE2==2~1, NEWRACE2==1~0, TRUE~NA_real_),
         female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0), college=ifelse(EDUHIGHCAT==4,1,0),
         poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(black), !is.na(w))
Y <- d$alcohol_days; A <- d$black; X <- as.matrix(d[,c("female","age_older","college","poverty_low")])
ps_f <- as.formula("A ~ female + age_older + college + poverty_low")
pgs_f <- as.formula("Y ~ female + age_older + college + poverty_low")
all_results$q7 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "black", "Q7")

# Q10: Hispanic vs White → Alcohol (employed, age 30-45)
cat("\n")
d <- data %>% filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, AGE3>=8, AGE3<=10, IRWRKSTAT18 %in% c(1,2)) %>%
  mutate(alcohol_days=as.numeric(ALCDAYS), hispanic=case_when(NEWRACE2==7~1, NEWRACE2==1~0, TRUE~NA_real_),
         female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0), college=ifelse(EDUHIGHCAT==4,1,0),
         poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(hispanic), !is.na(w))
Y <- d$alcohol_days; A <- d$hispanic; X <- as.matrix(d[,c("female","age_older","college","poverty_low")])
ps_f <- as.formula("A ~ female + age_older + college + poverty_low")
pgs_f <- as.formula("Y ~ female + age_older + college + poverty_low")
all_results$q10 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "hispanic", "Q10")

# Q11: Gender → Binge (employed, age 30-45)
cat("\n")
d <- data %>% filter(YEAR==2023, BNGDRMDAYS>=1, BNGDRMDAYS<=30, AGE3>=8, AGE3<=10, IRWRKSTAT18 %in% c(1,2)) %>%
  mutate(binge_days=as.numeric(BNGDRMDAYS), female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0),
         black=ifelse(NEWRACE2==2,1,0), hispanic=ifelse(NEWRACE2==7,1,0), college=ifelse(EDUHIGHCAT==4,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(female), !is.na(w))
Y <- d$binge_days; A <- d$female; X <- as.matrix(d[,c("age_older","black","hispanic","college")])
ps_f <- as.formula("A ~ age_older + black + hispanic + college")
pgs_f <- as.formula("Y ~ age_older + black + hispanic + college")
all_results$q11 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "female", "Q11")

# Q12: Urban vs Rural → Alcohol (employed, age 30-45)
cat("\n")
d <- data %>% filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, AGE3>=8, AGE3<=10, IRWRKSTAT18 %in% c(1,2)) %>%
  mutate(alcohol_days=as.numeric(ALCDAYS), urban=case_when(COUTYP4==1~1, COUTYP4==3~0, TRUE~NA_real_),
         female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0), black=ifelse(NEWRACE2==2,1,0),
         hispanic=ifelse(NEWRACE2==7,1,0), college=ifelse(EDUHIGHCAT==4,1,0),
         poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(urban), !is.na(w))
Y <- d$alcohol_days; A <- d$urban; X <- as.matrix(d[,c("female","age_older","black","hispanic","college","poverty_low")])
ps_f <- as.formula("A ~ female + age_older + black + hispanic + college + poverty_low")
pgs_f <- as.formula("Y ~ female + age_older + black + hispanic + college + poverty_low")
all_results$q12 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "urban", "Q12")

# Q13: Income → Marijuana (all users)
cat("\n")
d <- data %>% filter(YEAR==2023, MJDAY30A>=1, MJDAY30A<=30) %>%
  mutate(marijuana_days=as.numeric(MJDAY30A), high_income=case_when(IRFAMIN3>=5~1, IRFAMIN3<=2~0, TRUE~NA_real_),
         female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0), black=ifelse(NEWRACE2==2,1,0),
         hispanic=ifelse(NEWRACE2==7,1,0), college=ifelse(EDUHIGHCAT==4,1,0),
         unemployed=ifelse(IRWRKSTAT18==3,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(high_income), !is.na(w))
Y <- d$marijuana_days; A <- d$high_income; X <- as.matrix(d[,c("female","age_older","black","hispanic","college","unemployed")])
ps_f <- as.formula("A ~ female + age_older + black + hispanic + college + unemployed")
pgs_f <- as.formula("Y ~ female + age_older + black + hispanic + college + unemployed")
all_results$q13 <- run_all_7(d, Y, A, d$w, X, ps_f, pgs_f, "high_income", "Q13")

# ============================================================================
# SAVE RESULTS
# ============================================================================

saveRDS(all_results, "Analysis/Results/ALL_10_WITH_WDSM_VARIANTS_B200.rds")

cat("\n================================================================\n")
cat("✓ ALL 10 QUESTIONS COMPLETE WITH 7 METHODS EACH\n")
cat("✓ WDSM M=1, M=3, M=5 + DSM + PSM + PGM + PS Full\n")
cat("✓ Total: 70 analyses (10 questions × 7 methods)\n")
cat("================================================================\n")



