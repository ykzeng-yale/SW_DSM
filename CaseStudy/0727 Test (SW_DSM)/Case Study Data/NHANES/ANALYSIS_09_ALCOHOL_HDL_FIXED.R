################################################################################
# ANALYSIS 9: Alcohol → HDL
# ALL 5 METHODS
################################################################################

rm(list = ls())
library(dplyr); library(MatchIt); library(marginaleffects); library(survey)
if (!require(dsmatch)) { install.packages("dsmatch"); library(dsmatch) }
source("WDSM_adaptive.R")

set.seed(2024)
B_BOOTSTRAP <- 50

cat("\n===============================================================================\n")
cat("   ANALYSIS 9: Alcohol Consumption → HDL Cholesterol\n")
cat("===============================================================================\n\n")

load("data/nhanes_2007_2018.rda")

# Filter and prepare data - ages 40-70 for feasibility
analytic_data <- nhanes_2007_2018 %>%
  filter(!is.na(alq130), !is.na(lbdhdd), ridageyr >= 40, ridageyr <= 70)

cat("Initial N:", nrow(analytic_data), "\n")

Y <- analytic_data$lbdhdd
# Use MEDIAN SPLIT for alcohol consumption (high vs low drinkers)
alc_median <- median(analytic_data$alq130, na.rm=TRUE)
A <- ifelse(analytic_data$alq130 >= alc_median, 1, 0)  # High vs low alcohol
sw <- analytic_data$wtmec2yr

cat("Treatment (median split at", round(alc_median, 2), "drinks/day):\n")
cat("  High alcohol (≥median):", sum(A==1, na.rm=TRUE), "\n")
cat("  Low alcohol (<median):", sum(A==0, na.rm=TRUE), "\n")

# Covariates
ps_vars <- c("ridageyr", "riagendr", "ridreth1", "dmdeduc2", "indfmpir", "bmxbmi")
if("smq020" %in% names(analytic_data)) ps_vars <- c(ps_vars, "smq020")

complete_idx <- complete.cases(analytic_data[, c("lbdhdd", "alq130", ps_vars, "wtmec2yr")])
data_complete <- analytic_data[complete_idx, ]

Y <- data_complete$lbdhdd
alc_median_complete <- median(data_complete$alq130, na.rm=TRUE)
A <- ifelse(data_complete$alq130 >= alc_median_complete, 1, 0)
sw <- data_complete$wtmec2yr
X_ps <- as.matrix(data_complete[, ps_vars])
X_pg <- X_ps

cat("Complete cases: N =", nrow(data_complete), "\n\n")

results <- list()

cat("Method 1: DSM...")
dsm_r <- dsmatchATE(Y=Y, X=X_ps, A=A, method="dsm", model.ps="logit",
                    model.pg="linpred", lp.pg=X_pg, boots=B_BOOTSTRAP,
                    mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(dsm_r$bootvar)) dsm_r$bootvar[1,1] else dsm_r$bootvar
results$dsm <- list(estimate=dsm_r$est.ds, ci=dsm_r$est.ds + c(-1.96,1.96)*sqrt(bv))
cat(" Done\n")

cat("Method 2: PGM...")
pgm_r <- dsmatchATE(Y=Y, X=X_pg, A=A, method="pg", model.pg="glm",
                    boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(pgm_r$bootvar)) pgm_r$bootvar[1,1] else pgm_r$bootvar
results$pgm <- list(estimate=pgm_r$est.pg, ci=pgm_r$est.pg + c(-1.96,1.96)*sqrt(bv))
cat(" Done\n")

cat("Method 3: PSM...")
psm_r <- dsmatchATE(Y=Y, X=X_ps, A=A, method="ps", model.ps="logit",
                    boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(psm_r$bootvar)) psm_r$bootvar[1,1] else psm_r$bootvar
results$psm <- list(estimate=psm_r$est.ps, ci=psm_r$est.ps + c(-1.96,1.96)*sqrt(bv))
cat(" Done\n")

cat("Method 4: Weighted...")
df <- data.frame(Y=Y, A=A, sw=sw, data_complete[, ps_vars])
df$sw_norm <- df$sw * nrow(df) / sum(df$sw)
m <- matchit(as.formula(paste("A ~", paste(ps_vars, collapse=" + "))), data=df, method="full", estimand="ATE")
md <- match.data(m)
md$sw <- df$sw_norm[as.numeric(rownames(md))]
fit <- lm(as.formula(paste("Y ~ A * (", paste(ps_vars, collapse=" + "), ")")), data=md, weights=weights)
ate <- avg_comparisons(fit, variables="A", vcov=~subclass, wts="sw")
results$ps_full <- list(estimate=ate$estimate, ci=c(ate$conf.low, ate$conf.high))
cat(" Done\n")

cat("Method 5: WDSM...")
wdsm_data <- data_complete
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- sw
wdsm_boot <- bootstrap_adaptive_wdsm(data=wdsm_data,
                                     ps_formula=as.formula(paste("A ~", paste(ps_vars, collapse=" + "))),
                                     pg_formula=as.formula(paste("~", paste(ps_vars, collapse=" + "))),
                                     outcome_var="Y", treatment_var="A", weight_var="survey_weight",
                                     n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)
results$wdsm <- list(estimate=wdsm_boot$point_estimate$tau,  # Extract tau value!
                     ci=c(wdsm_boot$ci_lower, wdsm_boot$ci_upper))
cat(" Done\n\n")

# Calculate properly - ensure all are numeric scalars
sample_avg <- mean(c(as.numeric(results$dsm$estimate), 
                     as.numeric(results$pgm$estimate), 
                     as.numeric(results$psm$estimate)))
pop_avg <- mean(c(as.numeric(results$ps_full$estimate), 
                  as.numeric(results$wdsm$estimate)))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

cat("\nDEBUG - All values:\n")
cat("  DSM:", as.numeric(results$dsm$estimate), "\n")
cat("  PGM:", as.numeric(results$pgm$estimate), "\n")
cat("  PSM:", as.numeric(results$psm$estimate), "\n")
cat("  PS Full:", as.numeric(results$ps_full$estimate), "\n")
cat("  WDSM:", as.numeric(results$wdsm$estimate), "\n")
cat("  Sample avg:", sample_avg, "\n")
cat("  Pop avg:", pop_avg, "\n")
cat("  Bias:", bias_pct, "%\n\n")

save(data_complete, results, sample_avg, pop_avg, bias_pct, file="ANALYSIS_09_ALCOHOL_HDL_COMPLETE.rda")
cat("FILE SAVED: ANALYSIS_09_ALCOHOL_HDL_COMPLETE.rda\n")

cat("═══════════════════════════════════════════════════════════════════════════\n")
cat("ANALYSIS 9: Alcohol → HDL (N=", nrow(data_complete), ")\n")
cat("═══════════════════════════════════════════════════════════════════════════\n\n")
for(m in c('dsm','pgm','psm','ps_full','wdsm')) {
  r <- results[[m]]
  sig <- ifelse(r$ci[1]*r$ci[2] > 0, 'YES ✓', 'NO')
  cat(sprintf('%-25s  %6.2f   [%6.2f,%6.2f]   %6s   %s\n',
      c(dsm='Unweighted DSM', pgm='Unweighted PGM', psm='Unweighted PSM',
        ps_full='Survey-Weighted PS Full', wdsm='WDSM')[m],
      r$estimate, r$ci[1], r$ci[2], sig,
      ifelse(m %in% c('ps_full','wdsm'), 'Population', 'Sample')))
}
cat("Sample avg:", round(sample_avg,2), "| Pop avg:", round(pop_avg,2), "| Bias:", sprintf("%+.1f%%", bias_pct), "\n")
cat("\n✅ COMPLETE\n")

