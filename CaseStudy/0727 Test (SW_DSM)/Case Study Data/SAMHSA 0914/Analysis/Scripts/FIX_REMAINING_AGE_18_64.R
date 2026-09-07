#!/usr/bin/env Rscript

#' Add age 18-64 restriction to Q7, Q10, Q12 (scientifically justified for alcohol)
#' Q5 already has age 25+ which is appropriate for education question

suppressPackageStartupMessages({
  library(tidyverse); library(survey); library(MatchIt); library(marginaleffects); library(Matching)
})

invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("\n================================================================\n")
cat("Adding Age 18-64 Restriction to Q7, Q10, Q12\n")
cat("================================================================\n")
cat("Scientific justification: Working age adults (standard)\n")
cat("Q5 keeps age 25+ (appropriate for education analysis)\n")
cat("================================================================\n\n")

# Load existing results
ar <- readRDS('Analysis/Results/ALL_10_FULL_DATA_B200_FINAL.rds')

run_full <- function(d, Y, A, w, X, ps_f, pgs_f, tcol) {
  res <- list()
  
  cat("WDSM...")
  set.seed(2025)
  tryCatch({
    wdsm <- wdsm_flexible(d %>% mutate(Y=Y, Treatment=A), "Y", "Treatment", ps_f, pgs_f, "w", M=5, B=200, verbose=FALSE)
    res$wdsm <- wdsm
    cat("✓ ")
  }, error=function(e){res$wdsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗ ")})
  
  cat("DSM...")
  set.seed(2025)
  tryCatch({
    dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X, varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
    res$dsm <- list(estimate=dsm$est.ds, se=sqrt(dsm$bootvar[1,1]), ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]), ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]))
    cat("✓ ")
  }, error=function(e){res$dsm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗ ")})
  
  cat("PSM...")
  set.seed(2025)
  tryCatch({
    psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit", varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
    res$psm <- list(estimate=psm$est.ps, se=sqrt(psm$bootvar[1,1]), ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]), ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]))
    cat("✓ ")
  }, error=function(e){res$psm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗ ")})
  
  cat("PGM...")
  set.seed(2025)
  tryCatch({
    pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="linpred", lp.pg=X, varest=TRUE, boots=200, cov.balance=FALSE, mc=FALSE)
    res$pgm <- list(estimate=pgm$est.pg, se=sqrt(pgm$bootvar[1,1]), ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]), ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]))
    cat("✓ ")
  }, error=function(e){res$pgm <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗ ")})
  
  cat("PSFull...")
  set.seed(2025)
  tryCatch({
    d$sw <- d$w * nrow(d) / sum(d$w)
    m <- matchit(ps_f, data=d, method="full", estimand="ATE", s.weights=d$sw)
    md <- match.data(m)
    md$Y <- Y[as.numeric(rownames(md))]
    md$Treatment <- md[[tcol]]
    md$weights <- md$sw * md$weights
    cov_names <- all.vars(ps_f)[-1]
    formula_str <- paste("Y ~ Treatment * (", paste(cov_names, collapse=" + "), ")")
    fit <- lm(as.formula(formula_str), data=md, weights=weights)
    ate <- avg_comparisons(fit, variables="Treatment", vcov=~subclass, wts="sw")
    res$ps_full <- list(estimate=ate$estimate[1], se=ate$std.error[1], ci_lower=ate$conf.low[1], ci_upper=ate$conf.high[1])
    cat("✓\n")
  }, error=function(e){res$ps_full <- list(estimate=NA, se=NA, ci_lower=NA, ci_upper=NA); cat("✗\n")})
  
  return(res)
}

# Q7: Black vs White (add age 18-64)
cat("\nQ7: Black vs White → Alcohol (age 18-64)...")
d7 <- data %>%
  filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, CATAGE>=2, CATAGE<=5) %>%  # Age 18-64
  mutate(
    alcohol_days=as.numeric(ALCDAYS),
    black=case_when(NEWRACE2==2~1, NEWRACE2==1~0, TRUE~NA_real_),
    female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0),
    college=ifelse(EDUHIGHCAT==4,1,0), unemployed=ifelse(IRWRKSTAT18==3,1,0),
    poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1
  ) %>%
  filter(!is.na(black), !is.na(w))
cat("N=", nrow(d7), "\n")
Y <- d7$alcohol_days; A <- d7$black; X <- as.matrix(d7[,c("female","age_older","college","unemployed","poverty_low")])
ps_f <- as.formula("A~female+age_older+college+unemployed+poverty_low")
pgs_f <- as.formula("Y~female+age_older+college+unemployed+poverty_low")
ar$q7 <- run_full(d7, Y, A, d7$w, X, ps_f, pgs_f, "black")

# Q10: Hispanic vs White (add age 18-64)
cat("\nQ10: Hispanic vs White → Alcohol (age 18-64)...")
d10 <- data %>%
  filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, CATAGE>=2, CATAGE<=5) %>%  # Age 18-64
  mutate(
    alcohol_days=as.numeric(ALCDAYS),
    hispanic=case_when(NEWRACE2==7~1, NEWRACE2==1~0, TRUE~NA_real_),
    female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0),
    college=ifelse(EDUHIGHCAT==4,1,0), unemployed=ifelse(IRWRKSTAT18==3,1,0),
    poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1
  ) %>%
  filter(!is.na(hispanic), !is.na(w))
cat("N=", nrow(d10), "\n")
Y <- d10$alcohol_days; A <- d10$hispanic; X <- as.matrix(d10[,c("female","age_older","college","unemployed","poverty_low")])
ar$q10 <- run_full(d10, Y, A, d10$w, X, ps_f, pgs_f, "hispanic")

# Q12: Urban vs Rural (add age 18-64)
cat("\nQ12: Urban vs Rural → Alcohol (age 18-64)...")
d12 <- data %>%
  filter(YEAR==2023, ALCDAYS>=1, ALCDAYS<=365, CATAGE>=2, CATAGE<=5) %>%  # Age 18-64
  mutate(
    alcohol_days=as.numeric(ALCDAYS),
    urban=case_when(COUTYP4==1~1, COUTYP4==3~0, TRUE~NA_real_),
    female=ifelse(IRSEX==2,1,0), age_older=ifelse(AGE3>=10,1,0),
    black=ifelse(NEWRACE2==2,1,0), hispanic=ifelse(NEWRACE2==7,1,0),
    college=ifelse(EDUHIGHCAT==4,1,0), unemployed=ifelse(IRWRKSTAT18==3,1,0),
    poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0), w=ANALWT2_C1
  ) %>%
  filter(!is.na(urban), !is.na(w))
cat("N=", nrow(d12), "\n")
Y <- d12$alcohol_days; A <- d12$urban; X <- as.matrix(d12[,c("female","age_older","black","hispanic","college","unemployed","poverty_low")])
ps_f12 <- as.formula("A~female+age_older+black+hispanic+college+unemployed+poverty_low")
pgs_f12 <- as.formula("Y~female+age_older+black+hispanic+college+unemployed+poverty_low")
ar$q12 <- run_full(d12, Y, A, d12$w, X, ps_f12, pgs_f12, "urban")

saveRDS(ar, "Analysis/Results/ALL_10_FULLY_CORRECTED_B200.rds")

cat("\n================================================================\n")
cat("✓ Q7, Q10, Q12 RE-RUN WITH AGE 18-64\n")
cat("✓ ALL RESULTS SAVED\n")
cat("================================================================\n")




