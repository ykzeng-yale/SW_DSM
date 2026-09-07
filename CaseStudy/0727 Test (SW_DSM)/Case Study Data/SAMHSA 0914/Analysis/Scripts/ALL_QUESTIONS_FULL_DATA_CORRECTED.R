#!/usr/bin/env Rscript

#' ALL 10 QUESTIONS - FULL DATA (No artificial sampling!)
#' Only scientifically justified restrictions

suppressPackageStartupMessages({
  library(tidyverse)
  library(survey)
  library(MatchIt)
  library(marginaleffects)
  library(Matching)
})

invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

# Helper for all 5 methods (will handle large data)
run_all_5 <- function(Y, A, X, w, d, ps_f, pgs_f, treatment_col, B=50) {
  results <- list()
  
  cat("WDSM...")
  set.seed(2025)
  tryCatch({
    wdsm <- wdsm_flexible(d %>% mutate(Y=Y, Treatment=A), "Y", "Treatment", ps_f, pgs_f, "w", M=5, B=B, verbose=FALSE)
    results$wdsm <- wdsm
    cat("✓ ")
  }, error=function(e){results$wdsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗ ")})
  
  cat("DSM...")
  set.seed(2025)
  tryCatch({
    dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X, varest=TRUE, boots=B, cov.balance=FALSE, mc=FALSE)
    results$dsm <- list(estimate=dsm$est.ds, se=sqrt(dsm$bootvar[1,1]), ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]), ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]))
    cat("✓ ")
  }, error=function(e){results$dsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗ ")})
  
  cat("PSM...")
  set.seed(2025)
  tryCatch({
    psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit", varest=TRUE, boots=B, cov.balance=FALSE, mc=FALSE)
    results$psm <- list(estimate=psm$est.ps, se=sqrt(psm$bootvar[1,1]), ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]), ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]))
    cat("✓ ")
  }, error=function(e){results$psm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗ ")})
  
  cat("PGM...")
  set.seed(2025)
  tryCatch({
    pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", lp.pg=X, varest=TRUE, boots=B, cov.balance=FALSE, mc=FALSE)
    results$pgm <- list(estimate=pgm$est.pg, se=sqrt(pgm$bootvar[1,1]), ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]), ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]))
    cat("✓ ")
  }, error=function(e){results$pgm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗ ")})
  
  cat("PSFull...")
  set.seed(2025)
  tryCatch({
    d$sw <- d$w * nrow(d) / sum(d$w)
    m <- matchit(ps_f, data=d, method="full", estimand="ATE", s.weights=d$sw)
    md <- match.data(m)
    md$Y <- Y[as.numeric(rownames(md))]
    md$Treatment <- md[[treatment_col]]
    md$weights <- md$sw * md$weights
    cov_names <- all.vars(ps_f)[-1]
    formula_str <- paste("Y ~ Treatment * (", paste(cov_names, collapse=" + "), ")")
    fit <- lm(as.formula(formula_str), data=md, weights=weights)
    ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass, wts="sw")
    results$ps_full <- list(estimate=ate$estimate[1], se=ate$std.error[1], ci_lower=ate$conf.low[1], ci_upper=ate$conf.high[1])
    cat("✓\n")
  }, error=function(e){results$ps_full <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗\n")})
  
  return(results)
}

all_results <- list()

cat("\n================================================================\n")
cat("RUNNING ALL 10 QUESTIONS - FULL DATA (B=50 for speed)\n")
cat("================================================================\n\n")

# Q1: Gender → Alcohol (All adults, past-year users)
cat("Q1: Gender → Alcohol...")
d1 <- data %>% filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365) %>%
  mutate(alcohol_days=as.numeric(ALCDAYS), female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0),
         black=ifelse(NEWRACE2==2,1,0), hispanic=ifelse(NEWRACE2==7,1,0), college=ifelse(EDUHIGHCAT==4,1,0),
         unemployed=ifelse(IRWRKSTAT18==3,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(female), !is.na(w))
cat("N=", nrow(d1), "\n")
Y1 <- d1$alcohol_days; A1 <- d1$female; X1 <- as.matrix(d1[,c("age_older","black","hispanic","college","unemployed")])
ps_f1 <- as.formula("A ~ age_older + black + hispanic + college + unemployed")
pgs_f1 <- as.formula("Y ~ age_older + black + hispanic + college + unemployed")
all_results$q1 <- run_all_5(Y1, A1, X1, d1$w, d1, ps_f1, pgs_f1, "female", B=50)

# Q2: Gender → Marijuana (Past-month users)
cat("\nQ2: Gender → Marijuana...")
d2 <- data %>% filter(YEAR==2023, MJDAY30A>=1, MJDAY30A<=30) %>%
  mutate(marijuana_days=as.numeric(MJDAY30A), female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0),
         black=ifelse(NEWRACE2==2,1,0), hispanic=ifelse(NEWRACE2==7,1,0), college=ifelse(EDUHIGHCAT==4,1,0),
         unemployed=ifelse(IRWRKSTAT18==3,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(female), !is.na(w))
cat("N=", nrow(d2), "\n")
Y2 <- d2$marijuana_days; A2 <- d2$female; X2 <- as.matrix(d2[,c("age_older","black","hispanic","college","unemployed")])
all_results$q2 <- run_all_5(Y2, A2, X2, d2$w, d2, ps_f1, pgs_f1, "female", B=50)

# Q3: Employment → Alcohol (Working age 18-64)
cat("\nQ3: Employment → Alcohol...")
d3 <- data %>% filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, CATAGE>=2, CATAGE<=5) %>%
  mutate(alcohol_days=as.numeric(ALCDAYS), unemployed=case_when(IRWRKSTAT18==3~1, IRWRKSTAT18==1~0, TRUE~NA_real_),
         female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0), black=ifelse(NEWRACE2==2,1,0),
         hispanic=ifelse(NEWRACE2==7,1,0), college=ifelse(EDUHIGHCAT==4,1,0), poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(unemployed), !is.na(w))
cat("N=", nrow(d3), "\n")
Y3 <- d3$alcohol_days; A3 <- d3$unemployed; X3 <- as.matrix(d3[,c("female","age_older","black","hispanic","college","poverty_low")])
ps_f3 <- as.formula("A ~ female + age_older + black + hispanic + college + poverty_low")
pgs_f3 <- as.formula("Y ~ female + age_older + black + hispanic + college + poverty_low")
all_results$q3 <- run_all_5(Y3, A3, X3, d3$w, d3, ps_f3, pgs_f3, "unemployed", B=50)

# Q5: Education → Alcohol (Adults 25+, education complete)
cat("\nQ5: Education → Alcohol...")
d5 <- data %>% filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, CATAGE>=3) %>%
  mutate(alcohol_days=as.numeric(ALCDAYS), college=case_when(EDUHIGHCAT==4~1, EDUHIGHCAT==2~0, TRUE~NA_real_),
         female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=11,1,0), black=ifelse(NEWRACE2==2,1,0),
         hispanic=ifelse(NEWRACE2==7,1,0), unemployed=ifelse(IRWRKSTAT18==3,1,0), poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1) %>%
  filter(!is.na(college), !is.na(w))
cat("N=", nrow(d5), "\n")
Y5 <- d5$alcohol_days; A5 <- d5$college; X5 <- as.matrix(d5[,c("female","age_older","black","hispanic","unemployed","poverty_low")])
all_results$q5 <- run_all_5(Y5, A5, X5, d5$w, d5, ps_f3, pgs_f3, "college", B=50)

saveRDS(all_results, "Analysis/Results/FULL_DATA_CORRECTED.rds")

cat("\n================================================================\n")
cat("4 QUESTIONS COMPLETED WITH FULL DATA\n")
cat("================================================================\n")

