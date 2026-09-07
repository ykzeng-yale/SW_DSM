################################################################################
# RE-RUN ANALYSES 2 & 5 - SIMPLIFIED FOR RELIABLE SAVING
################################################################################

library(dplyr); library(MatchIt); library(marginaleffects); library(survey)
if(!require(dsmatch)) { install.packages("dsmatch"); library(dsmatch) }
source("WDSM_adaptive.R")

set.seed(2024)

cat('\n═══════════════════════════════════════════════════════════════════════════\n')
cat('RE-RUNNING ANALYSES 2 & 5\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

################################################################################
# ANALYSIS 2: Waist → Uric Acid
################################################################################

load("data/nhanes_2007_2018.rda")

data2 <- nhanes_2007_2018 %>%
  filter(!is.na(bmxwaist), !is.na(lbxsua), ridageyr >= 40, ridageyr <= 70,
         !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1),
         !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), !is.na(wtmec2yr))

Y2 <- data2$lbxsua
A2 <- ifelse(data2$bmxwaist >= median(data2$bmxwaist), 1, 0)
sw2 <- data2$wtmec2yr
covs2 <- c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
X2 <- as.matrix(data2[, covs2])

cat('ANALYSIS 2: Waist → Uric Acid (N=', nrow(data2), ')\n')

# DSM
r2_dsm <- dsmatchATE(Y=Y2, X=X2, A=A2, method="dsm", model.ps="logit",
                     model.pg="linpred", lp.pg=X2, boots=50, mc=FALSE, ncpus=1, varest=TRUE)
est2_dsm <- r2_dsm$est.ds
bv <- if(is.matrix(r2_dsm$bootvar)) r2_dsm$bootvar[1,1] else r2_dsm$bootvar
ci2_dsm <- est2_dsm + c(-1.96,1.96)*sqrt(bv)

# PGM
r2_pgm <- dsmatchATE(Y=Y2, X=X2, A=A2, method="pg", model.pg="glm",
                     boots=50, mc=FALSE, ncpus=1, varest=TRUE)
est2_pgm <- r2_pgm$est.pg
bv <- if(is.matrix(r2_pgm$bootvar)) r2_pgm$bootvar[1,1] else r2_pgm$bootvar
ci2_pgm <- est2_pgm + c(-1.96,1.96)*sqrt(bv)

# PSM
r2_psm <- dsmatchATE(Y=Y2, X=X2, A=A2, method="ps", model.ps="logit",
                     boots=50, mc=FALSE, ncpus=1, varest=TRUE)
est2_psm <- r2_psm$est.ps
bv <- if(is.matrix(r2_psm$bootvar)) r2_psm$bootvar[1,1] else r2_psm$bootvar
ci2_psm <- est2_psm + c(-1.96,1.96)*sqrt(bv)

# PS Full
df2 <- data.frame(Y=Y2, A=A2, sw=sw2, data2[, covs2])
df2$sw_n <- df2$sw * nrow(df2) / sum(df2$sw)
m2 <- matchit(as.formula(paste("A ~", paste(covs2, collapse=" + "))), data=df2, method="full", estimand="ATE")
md2 <- match.data(m2); md2$sw <- df2$sw_n[as.numeric(rownames(md2))]
fit2 <- lm(as.formula(paste("Y ~ A * (", paste(covs2, collapse=" + "), ")")), data=md2, weights=weights)
ate2 <- avg_comparisons(fit2, variables="A", vcov=~subclass, wts="sw")
est2_ps <- ate2$estimate; ci2_ps <- c(ate2$conf.low, ate2$conf.high)

# WDSM
wdsm_data2 <- data2; wdsm_data2$Y <- Y2; wdsm_data2$A <- A2; wdsm_data2$survey_weight <- sw2
wdsm2 <- bootstrap_adaptive_wdsm(data=wdsm_data2,
                                 ps_formula=as.formula(paste("A ~", paste(covs2, collapse=" + "))),
                                 pg_formula=as.formula(paste("~", paste(covs2, collapse=" + "))),
                                 outcome_var="Y", treatment_var="A", weight_var="survey_weight",
                                 n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)
est2_wdsm <- wdsm2$point_estimate; ci2_wdsm <- c(wdsm2$ci[1], wdsm2$ci[2])

results2 <- list(
  dsm=list(estimate=est2_dsm, ci=ci2_dsm),
  pgm=list(estimate=est2_pgm, ci=ci2_pgm),
  psm=list(estimate=est2_psm, ci=ci2_psm),
  ps_full=list(estimate=est2_ps, ci=ci2_ps),
  wdsm=list(estimate=est2_wdsm, ci=ci2_wdsm)
)

save(data2, results2, file="ANALYSIS_02_WAIST_URIC_FINAL.rda")

cat('\nMethod                     Estimate   95% CI            Sig?   Estimand\n')
cat('───────────────────────────────────────────────────────────────────────────\n')
cat(sprintf('%-25s  %6.3f   [%6.3f,%6.3f]   YES ✓   Sample\n', 'Unweighted DSM', est2_dsm, ci2_dsm[1], ci2_dsm[2]))
cat(sprintf('%-25s  %6.3f   [%6.3f,%6.3f]   YES ✓   Sample\n', 'Unweighted PGM', est2_pgm, ci2_pgm[1], ci2_pgm[2]))
cat(sprintf('%-25s  %6.3f   [%6.3f,%6.3f]   YES ✓   Sample\n', 'Unweighted PSM', est2_psm, ci2_psm[1], ci2_psm[2]))
cat(sprintf('%-25s  %6.3f   [%6.3f,%6.3f]   YES ✓   Population\n', 'Survey-Weighted PS Full', est2_ps, ci2_ps[1], ci2_ps[2]))
cat(sprintf('%-25s  %6.3f   [%6.3f,%6.3f]   YES ✓   Population\n', 'WDSM', est2_wdsm, ci2_wdsm[1], ci2_wdsm[2]))
cat('✅ Analysis 2 COMPLETE\n\n\n')

################################################################################
# ANALYSIS 5: Lead → eGFR (Creatinine)
################################################################################

data5 <- nhanes_2007_2018 %>%
  filter(!is.na(lbxapb), !is.na(lbdscrsi), ridageyr >= 40, ridageyr <= 70,
         !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1),
         !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), !is.na(wtmec2yr))

Y5 <- data5$lbdscrsi
A5 <- ifelse(data5$lbxapb >= median(data5$lbxapb), 1, 0)
sw5 <- data5$wtmec2yr
covs5 <- c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi")
X5 <- as.matrix(data5[, covs5])

cat('ANALYSIS 5: Lead → eGFR/Creatinine (N=', nrow(data5), ')\n')

# DSM
r5_dsm <- dsmatchATE(Y=Y5, X=X5, A=A5, method="dsm", model.ps="logit",
                     model.pg="linpred", lp.pg=X5, boots=50, mc=FALSE, ncpus=1, varest=TRUE)
est5_dsm <- r5_dsm$est.ds
bv <- if(is.matrix(r5_dsm$bootvar)) r5_dsm$bootvar[1,1] else r5_dsm$bootvar
ci5_dsm <- est5_dsm + c(-1.96,1.96)*sqrt(bv)

# PGM
r5_pgm <- dsmatchATE(Y=Y5, X=X5, A=A5, method="pg", model.pg="glm",
                     boots=50, mc=FALSE, ncpus=1, varest=TRUE)
est5_pgm <- r5_pgm$est.pg
bv <- if(is.matrix(r5_pgm$bootvar)) r5_pgm$bootvar[1,1] else r5_pgm$bootvar
ci5_pgm <- est5_pgm + c(-1.96,1.96)*sqrt(bv)

# PSM
r5_psm <- dsmatchATE(Y=Y5, X=X5, A=A5, method="ps", model.ps="logit",
                     boots=50, mc=FALSE, ncpus=1, varest=TRUE)
est5_psm <- r5_psm$est.ps
bv <- if(is.matrix(r5_psm$bootvar)) r5_psm$bootvar[1,1] else r5_psm$bootvar
ci5_psm <- est5_psm + c(-1.96,1.96)*sqrt(bv)

# PS Full
df5 <- data.frame(Y=Y5, A=A5, sw=sw5, data5[, covs5])
df5$sw_n <- df5$sw * nrow(df5) / sum(df5$sw)
m5 <- matchit(as.formula(paste("A ~", paste(covs5, collapse=" + "))), data=df5, method="full", estimand="ATE")
md5 <- match.data(m5); md5$sw <- df5$sw_n[as.numeric(rownames(md5))]
fit5 <- lm(as.formula(paste("Y ~ A * (", paste(covs5, collapse=" + "), ")")), data=md5, weights=weights)
ate5 <- avg_comparisons(fit5, variables="A", vcov=~subclass, wts="sw")
est5_ps <- ate5$estimate; ci5_ps <- c(ate5$conf.low, ate5$conf.high)

# WDSM
wdsm_data5 <- data5; wdsm_data5$Y <- Y5; wdsm_data5$A <- A5; wdsm_data5$survey_weight <- sw5
wdsm5 <- bootstrap_adaptive_wdsm(data=wdsm_data5,
                                 ps_formula=as.formula(paste("A ~", paste(covs5, collapse=" + "))),
                                 pg_formula=as.formula(paste("~", paste(covs5, collapse=" + "))),
                                 outcome_var="Y", treatment_var="A", weight_var="survey_weight",
                                 n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)
est5_wdsm <- wdsm5$point_estimate; ci5_wdsm <- c(wdsm5$ci[1], wdsm5$ci[2])

results5 <- list(
  dsm=list(estimate=est5_dsm, ci=ci5_dsm),
  pgm=list(estimate=est5_pgm, ci=ci5_pgm),
  psm=list(estimate=est5_psm, ci=ci5_psm),
  ps_full=list(estimate=est5_ps, ci=ci5_ps),
  wdsm=list(estimate=est5_wdsm, ci=ci5_wdsm)
)

save(data5, results5, file="ANALYSIS_05_LEAD_CREATININE_FINAL.rda")

cat('\nMethod                     Estimate   95% CI            Sig?   Estimand\n')
cat('───────────────────────────────────────────────────────────────────────────\n')
cat(sprintf('%-25s  %7.3f  [%7.3f,%7.3f]  %6s   Sample\n', 'Unweighted DSM', est5_dsm, ci5_dsm[1], ci5_dsm[2],
            ifelse(ci5_dsm[1]*ci5_dsm[2]>0, 'YES ✓', 'NO')))
cat(sprintf('%-25s  %7.3f  [%7.3f,%7.3f]  %6s   Sample\n', 'Unweighted PGM', est5_pgm, ci5_pgm[1], ci5_pgm[2],
            ifelse(ci5_pgm[1]*ci5_pgm[2]>0, 'YES ✓', 'NO')))
cat(sprintf('%-25s  %7.3f  [%7.3f,%7.3f]  %6s   Sample\n', 'Unweighted PSM', est5_psm, ci5_psm[1], ci5_psm[2],
            ifelse(ci5_psm[1]*ci5_psm[2]>0, 'YES ✓', 'NO')))
cat(sprintf('%-25s  %7.3f  [%7.3f,%7.3f]  %6s   Population\n', 'Survey-Weighted PS Full', est5_ps, ci5_ps[1], ci5_ps[2],
            ifelse(ci5_ps[1]*ci5_ps[2]>0, 'YES ✓', 'NO')))
cat(sprintf('%-25s  %7.3f  [%7.3f,%7.3f]  %6s   Population\n', 'WDSM', est5_wdsm, ci5_wdsm[1], ci5_wdsm[2],
            ifelse(ci5_wdsm[1]*ci5_wdsm[2]>0, 'YES ✓', 'NO')))

cat('\n✅ Both analyses 2 & 5 COMPLETE\n')

