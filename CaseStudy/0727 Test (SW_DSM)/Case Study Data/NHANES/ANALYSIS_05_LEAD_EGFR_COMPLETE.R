################################################################################
# ANALYSIS 5: Lead Exposure → eGFR
# ALL 5 METHODS
################################################################################

rm(list = ls())
library(dplyr); library(MatchIt); library(marginaleffects); library(survey)
if (!require(dsmatch)) { install.packages("dsmatch"); library(dsmatch) }
source("WDSM_adaptive.R")

set.seed(2024)
B_BOOTSTRAP <- 50

cat("\n===============================================================================\n")
cat("   ANALYSIS 5: Lead Exposure → eGFR\n")
cat("===============================================================================\n\n")

load("data/nhanes_2007_2018.rda")

# Use lbxapb (lead variable verified) - restrict age range
analytic_data <- nhanes_2007_2018 %>%
  filter(!is.na(lbxapb), !is.na(lbdscrsi), ridageyr >= 40 & ridageyr <= 70)

lead_var <- "lbxapb"

Y <- analytic_data$lbdscrsi  # Serum creatinine (eGFR calculated from this)
lead_median <- median(analytic_data[[lead_var]], na.rm=TRUE)
A <- ifelse(analytic_data[[lead_var]] >= lead_median, 1, 0)
sw <- analytic_data$wtmec2yr

ps_vars <- c("ridageyr", "riagendr", "ridreth1", "bmxbmi", "dmdeduc2", "indfmpir")
complete_idx <- complete.cases(analytic_data[, c("lbdscrsi", lead_var, ps_vars, "wtmec2yr")])
data_complete <- analytic_data[complete_idx, ]

Y <- data_complete$lbdscrsi; A <- ifelse(data_complete[[lead_var]] >= lead_median, 1, 0)
sw <- data_complete$wtmec2yr; X_ps <- as.matrix(data_complete[, ps_vars]); X_pg <- X_ps

cat("N =", nrow(data_complete), "| High lead:", sum(A==1), "| Low lead:", sum(A==0), "\n\n")

results <- list()

cat("Method 1: DSM..."); dsm_r <- dsmatchATE(Y=Y, X=X_ps, A=A, method="dsm", model.ps="logit",
    model.pg="linpred", lp.pg=X_pg, boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(dsm_r$bootvar)) dsm_r$bootvar[1,1] else dsm_r$bootvar
results$dsm <- list(estimate=dsm_r$est.ds, ci=dsm_r$est.ds + c(-1.96,1.96)*sqrt(bv)); cat(" Done\n")

cat("Method 2: PGM..."); pgm_r <- dsmatchATE(Y=Y, X=X_pg, A=A, method="pg", model.pg="glm",
    boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(pgm_r$bootvar)) pgm_r$bootvar[1,1] else pgm_r$bootvar
results$pgm <- list(estimate=pgm_r$est.pg, ci=pgm_r$est.pg + c(-1.96,1.96)*sqrt(bv)); cat(" Done\n")

cat("Method 3: PSM..."); psm_r <- dsmatchATE(Y=Y, X=X_ps, A=A, method="ps", model.ps="logit",
    boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(psm_r$bootvar)) psm_r$bootvar[1,1] else psm_r$bootvar
results$psm <- list(estimate=psm_r$est.ps, ci=psm_r$est.ps + c(-1.96,1.96)*sqrt(bv)); cat(" Done\n")

cat("Method 4: Weighted..."); df <- data.frame(Y=Y, A=A, sw=sw, data_complete[, ps_vars])
df$sw_norm <- df$sw * nrow(df) / sum(df$sw)
m <- matchit(as.formula(paste("A ~", paste(ps_vars, collapse=" + "))), data=df, method="full", estimand="ATE")
md <- match.data(m); md$sw <- df$sw_norm[as.numeric(rownames(md))]
fit <- lm(as.formula(paste("Y ~ A * (", paste(ps_vars, collapse=" + "), ")")), data=md, weights=weights)
ate <- avg_comparisons(fit, variables="A", vcov=~subclass, wts="sw")
results$ps_full <- list(estimate=ate$estimate, ci=c(ate$conf.low, ate$conf.high)); cat(" Done\n")

cat("Method 5: WDSM..."); wdsm_data <- data_complete; wdsm_data$Y <- Y; wdsm_data$A <- A; wdsm_data$survey_weight <- sw
wdsm_boot <- bootstrap_adaptive_wdsm(data=wdsm_data,
    ps_formula=as.formula(paste("A ~", paste(ps_vars, collapse=" + "))),
    pg_formula=as.formula(paste("~", paste(ps_vars, collapse=" + "))),
    outcome_var="Y", treatment_var="A", weight_var="survey_weight",
    n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)
results$wdsm <- list(estimate=wdsm_boot$point_estimate, ci=c(wdsm_boot$ci[1], wdsm_boot$ci[2])); cat(" Done\n\n")

sample_avg <- mean(c(results$dsm$estimate, results$pgm$estimate, results$psm$estimate))
pop_avg <- mean(c(results$ps_full$estimate, results$wdsm$estimate))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

save(data_complete, results, sample_avg, pop_avg, bias_pct, file="ANALYSIS_04_MVPA_HBA1C_COMPLETE.rda")

cat("═══════════════════════════════════════════════════════════════════════════\n")
cat("ANALYSIS 4: MVPA → HbA1c (N=", nrow(data_complete), ")\n")
cat("═══════════════════════════════════════════════════════════════════════════\n\n")
for(m in c('dsm','pgm','psm','ps_full','wdsm')) {
  r <- results[[m]]; sig <- ifelse(abs(r$ci[1])>0 & abs(r$ci[2])>0 & sign(r$ci[1])==sign(r$ci[2]), 'YES ✓', 'NO')
  cat(sprintf('%-25s  %7.3f  [%7.3f,%7.3f]  %6s   %s\n',
      c(dsm='Unweighted DSM', pgm='Unweighted PGM', psm='Unweighted PSM',
        ps_full='Survey-Weighted PS Full', wdsm='WDSM')[m],
      r$estimate, r$ci[1], r$ci[2], sig,
      ifelse(m %in% c('ps_full','wdsm'), 'Population', 'Sample')))
}
cat("Sample avg:", round(sample_avg,3), "| Pop avg:", round(pop_avg,3), "| Bias:", sprintf("%+.1f%%", bias_pct), "\n✅ COMPLETE\n")

