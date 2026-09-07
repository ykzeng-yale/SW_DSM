################################################################################
# ANALYSES 8, 9, 10: Obesity→ALT, Alcohol→HDL, Sleep→HbA1c
# ALL 5 METHODS EACH
################################################################################

rm(list = ls())
library(dplyr); library(MatchIt); library(marginaleffects); library(survey)
if (!require(dsmatch)) { install.packages("dsmatch"); library(dsmatch) }
source("WDSM_adaptive.R")

set.seed(2024)
B_BOOTSTRAP <- 50

load("data/nhanes_2007_2018.rda")

cat("\n═══════════════════════════════════════════════════════════════════════════\n")
cat("   RUNNING ANALYSES 8, 9, 10\n")
cat("═══════════════════════════════════════════════════════════════════════════\n\n")

################################################################################
# ANALYSIS 8: Obesity → ALT
################################################################################

cat("ANALYSIS 8: Obesity → ALT\n")
d8 <- nhanes_2007_2018 %>% filter(!is.na(bmxbmi), !is.na(lbxsatsi), ridageyr>=40, ridageyr<=70,
         lbxsatsi>0 & lbxsatsi<300, !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1),
         !is.na(dmdeduc2), !is.na(indfmpir), !is.na(wtmec2yr))
Y8 <- d8$lbxsatsi; A8 <- ifelse(d8$bmxbmi>=30, 1, 0); sw8 <- d8$wtmec2yr
covs8 <- c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir")
if("smq020" %in% names(d8) && sum(!is.na(d8$smq020))>1000) {d8 <- d8 %>% filter(!is.na(smq020)); covs8 <- c(covs8,"smq020")}
if("alq130" %in% names(d8) && sum(!is.na(d8$alq130))>1000) {d8 <- d8 %>% filter(!is.na(alq130)); covs8 <- c(covs8,"alq130")}
Y8 <- d8$lbxsatsi; A8 <- ifelse(d8$bmxbmi>=30,1,0); sw8 <- d8$wtmec2yr; X8 <- as.matrix(d8[,covs8])

cat("N=",nrow(d8),"\n")

r8_dsm <- dsmatchATE(Y=Y8, X=X8, A=A8, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X8, boots=50, mc=FALSE, ncpus=1, varest=TRUE)
r8_pgm <- dsmatchATE(Y=Y8, X=X8, A=A8, method="pg", model.pg="glm", boots=50, mc=FALSE, ncpus=1, varest=TRUE)
r8_psm <- dsmatchATE(Y=Y8, X=X8, A=A8, method="ps", model.ps="logit", boots=50, mc=FALSE, ncpus=1, varest=TRUE)

df8 <- data.frame(Y=Y8, A=A8, sw=sw8, d8[,covs8]); df8$sw_n <- df8$sw*nrow(df8)/sum(df8$sw)
m8 <- matchit(as.formula(paste("A~",paste(covs8,collapse="+"))), data=df8, method="full", estimand="ATE")
md8 <- match.data(m8); md8$sw <- df8$sw_n[as.numeric(rownames(md8))]
fit8 <- lm(as.formula(paste("Y~A*(",paste(covs8,collapse="+"),")")), data=md8, weights=weights)
ate8 <- avg_comparisons(fit8, variables="A", vcov=~subclass, wts="sw")

wd8 <- d8; wd8$Y<-Y8; wd8$A<-A8; wd8$survey_weight<-sw8
w8 <- bootstrap_adaptive_wdsm(data=wd8, ps_formula=as.formula(paste("A~",paste(covs8,collapse="+"))),
      pg_formula=as.formula(paste("~",paste(covs8,collapse="+"))),
      outcome_var="Y", treatment_var="A", weight_var="survey_weight",
      n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)

results8 <- list(
  dsm=list(estimate=r8_dsm$est.ds, ci=r8_dsm$est.ds+c(-1.96,1.96)*sqrt(if(is.matrix(r8_dsm$bootvar)) r8_dsm$bootvar[1,1] else r8_dsm$bootvar)),
  pgm=list(estimate=r8_pgm$est.pg, ci=r8_pgm$est.pg+c(-1.96,1.96)*sqrt(if(is.matrix(r8_pgm$bootvar)) r8_pgm$bootvar[1,1] else r8_pgm$bootvar)),
  psm=list(estimate=r8_psm$est.ps, ci=r8_psm$est.ps+c(-1.96,1.96)*sqrt(if(is.matrix(r8_psm$bootvar)) r8_psm$bootvar[1,1] else r8_psm$bootvar)),
  ps_full=list(estimate=ate8$estimate, ci=c(ate8$conf.low, ate8$conf.high)),
  wdsm=list(estimate=w8$point_estimate, ci=c(w8$ci[1], w8$ci[2]))
)

save(d8, results8, file="ANALYSIS_08_OBESITY_ALT_COMPLETE.rda")
cat("Analysis 8 COMPLETE\n\n")

################################################################################
# ANALYSIS 9: Alcohol → HDL
################################################################################

cat("ANALYSIS 9: Alcohol → HDL\n")
d9 <- nhanes_2007_2018 %>% filter(!is.na(alq130), !is.na(lbdhdd), ridageyr>=40, ridageyr<=70,
         !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1),
         !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), !is.na(wtmec2yr))
Y9 <- d9$lbdhdd; A9 <- ifelse(d9$alq130>0, 1, 0); sw9 <- d9$wtmec2yr
covs9 <- c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
if("smq020" %in% names(d9)) {d9 <- d9 %>% filter(!is.na(smq020)); covs9 <- c(covs9,"smq020")}
Y9 <- d9$lbdhdd; A9 <- ifelse(d9$alq130>0,1,0); sw9 <- d9$wtmec2yr; X9 <- as.matrix(d9[,covs9])

cat("N=",nrow(d9),"\n")

r9_dsm <- dsmatchATE(Y=Y9, X=X9, A=A9, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X9, boots=50, mc=FALSE, ncpus=1, varest=TRUE)
r9_pgm <- dsmatchATE(Y=Y9, X=X9, A=A9, method="pg", model.pg="glm", boots=50, mc=FALSE, ncpus=1, varest=TRUE)
r9_psm <- dsmatchATE(Y=Y9, X=X9, A=A9, method="ps", model.ps="logit", boots=50, mc=FALSE, ncpus=1, varest=TRUE)

df9 <- data.frame(Y=Y9, A=A9, sw=sw9, d9[,covs9]); df9$sw_n <- df9$sw*nrow(df9)/sum(df9$sw)
m9 <- matchit(as.formula(paste("A~",paste(covs9,collapse="+"))), data=df9, method="full", estimand="ATE")
md9 <- match.data(m9); md9$sw <- df9$sw_n[as.numeric(rownames(md9))]
fit9 <- lm(as.formula(paste("Y~A*(",paste(covs9,collapse="+"),")")), data=md9, weights=weights)
ate9 <- avg_comparisons(fit9, variables="A", vcov=~subclass, wts="sw")

wd9 <- d9; wd9$Y<-Y9; wd9$A<-A9; wd9$survey_weight<-sw9
w9 <- bootstrap_adaptive_wdsm(data=wd9, ps_formula=as.formula(paste("A~",paste(covs9,collapse="+"))),
      pg_formula=as.formula(paste("~",paste(covs9,collapse="+"))),
      outcome_var="Y", treatment_var="A", weight_var="survey_weight",
      n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)

results9 <- list(
  dsm=list(estimate=r9_dsm$est.ds, ci=r9_dsm$est.ds+c(-1.96,1.96)*sqrt(if(is.matrix(r9_dsm$bootvar)) r9_dsm$bootvar[1,1] else r9_dsm$bootvar)),
  pgm=list(estimate=r9_pgm$est.pg, ci=r9_pgm$est.pg+c(-1.96,1.96)*sqrt(if(is.matrix(r9_pgm$bootvar)) r9_pgm$bootvar[1,1] else r9_pgm$bootvar)),
  psm=list(estimate=r9_psm$est.ps, ci=r9_psm$est.ps+c(-1.96,1.96)*sqrt(if(is.matrix(r9_psm$bootvar)) r9_psm$bootvar[1,1] else r9_psm$bootvar)),
  ps_full=list(estimate=ate9$estimate, ci=c(ate9$conf.low, ate9$conf.high)),
  wdsm=list(estimate=w9$point_estimate, ci=c(w9$ci[1], w9$ci[2]))
)

save(d9, results9, file="ANALYSIS_09_ALCOHOL_HDL_COMPLETE.rda")
cat("Analysis 9 COMPLETE\n\n")

################################################################################
# ANALYSIS 10: Sleep → HbA1c
################################################################################

cat("ANALYSIS 10: Sleep → HbA1c\n")
d10 <- nhanes_2007_2018 %>% filter(!is.na(sld012), !is.na(lbxgh), ridageyr>=40, ridageyr<=70,
          !is.na(diq010), diq010!=1,  # Non-diabetics
          !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1),
          !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), !is.na(wtmec2yr))
Y10 <- d10$lbxgh; A10 <- ifelse(d10$sld012<7, 1, 0); sw10 <- d10$wtmec2yr  # Short sleep vs adequate
covs10 <- c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
if("smq020" %in% names(d10)) {d10 <- d10 %>% filter(!is.na(smq020)); covs10 <- c(covs10,"smq020")}
Y10 <- d10$lbxgh; A10 <- ifelse(d10$sld012<7,1,0); sw10 <- d10$wtmec2yr; X10 <- as.matrix(d10[,covs10])

cat("N=",nrow(d10),"\n")

r10_dsm <- dsmatchATE(Y=Y10, X=X10, A=A10, method="dsm", model.ps="logit", model.pg="linpred", lp.pg=X10, boots=50, mc=FALSE, ncpus=1, varest=TRUE)
r10_pgm <- dsmatchATE(Y=Y10, X=X10, A=A10, method="pg", model.pg="glm", boots=50, mc=FALSE, ncpus=1, varest=TRUE)
r10_psm <- dsmatchATE(Y=Y10, X=X10, A=A10, method="ps", model.ps="logit", boots=50, mc=FALSE, ncpus=1, varest=TRUE)

df10 <- data.frame(Y=Y10, A=A10, sw=sw10, d10[,covs10]); df10$sw_n <- df10$sw*nrow(df10)/sum(df10$sw)
m10 <- matchit(as.formula(paste("A~",paste(covs10,collapse="+"))), data=df10, method="full", estimand="ATE")
md10 <- match.data(m10); md10$sw <- df10$sw_n[as.numeric(rownames(md10))]
fit10 <- lm(as.formula(paste("Y~A*(",paste(covs10,collapse="+"),")")), data=md10, weights=weights)
ate10 <- avg_comparisons(fit10, variables="A", vcov=~subclass, wts="sw")

wd10 <- d10; wd10$Y<-Y10; wd10$A<-A10; wd10$survey_weight<-sw10
w10 <- bootstrap_adaptive_wdsm(data=wd10, ps_formula=as.formula(paste("A~",paste(covs10,collapse="+"))),
       pg_formula=as.formula(paste("~",paste(covs10,collapse="+"))),
       outcome_var="Y", treatment_var="A", weight_var="survey_weight",
       n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)

results8 <- NULL; results9 <- NULL; results10 <- list(
  dsm=list(estimate=r10_dsm$est.ds, ci=r10_dsm$est.ds+c(-1.96,1.96)*sqrt(if(is.matrix(r10_dsm$bootvar)) r10_dsm$bootvar[1,1] else r10_dsm$bootvar)),
  pgm=list(estimate=r10_pgm$est.pg, ci=r10_pgm$est.pg+c(-1.96,1.96)*sqrt(if(is.matrix(r10_pgm$bootvar)) r10_pgm$bootvar[1,1] else r10_pgm$bootvar)),
  psm=list(estimate=r10_psm$est.ps, ci=r10_psm$est.ps+c(-1.96,1.96)*sqrt(if(is.matrix(r10_psm$bootvar)) r10_psm$bootvar[1,1] else r10_psm$bootvar)),
  ps_full=list(estimate=ate10$estimate, ci=c(ate10$conf.low, ate10$conf.high)),
  wdsm=list(estimate=w10$point_estimate, ci=c(w10$ci[1], w10$ci[2]))
)

save(d10, results10, file="ANALYSIS_10_SLEEP_HBA1C_COMPLETE.rda")
cat("Analysis 10 COMPLETE\n")

