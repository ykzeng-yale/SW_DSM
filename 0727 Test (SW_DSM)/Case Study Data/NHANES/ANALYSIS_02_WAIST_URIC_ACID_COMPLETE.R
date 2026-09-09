################################################################################
# ANALYSIS 2: Waist Circumference → Uric Acid
# ALL 5 METHODS (Following Lin 2024 template exactly)
################################################################################

rm(list = ls())
library(dplyr)
library(MatchIt)
library(marginaleffects)
library(survey)

if (!require(dsmatch)) {
  install.packages("dsmatch")
  library(dsmatch)
}

source("WDSM_adaptive.R")

set.seed(2024)
B_BOOTSTRAP <- 50  # Fast version

cat("\n===============================================================================\n")
cat("   ANALYSIS 2: Waist Circumference → Uric Acid\n")
cat("   ALL 5 MATCHING METHODS\n")
cat("===============================================================================\n")

# Load data
load("data/nhanes_2007_2018.rda")

# Prepare data - restrict to ages 40-70 to reduce sample size for full matching
analytic_data <- nhanes_2007_2018 %>%
  filter(
    !is.na(bmxwaist),
    !is.na(lbxsua),
    ridageyr >= 40 & ridageyr <= 70  # Restrict age range for computational feasibility
  )

cat("\nSample: N =", nrow(analytic_data), "\n")
cat("Mean waist:", round(mean(analytic_data$bmxwaist, na.rm=TRUE), 1), "cm\n")
cat("Mean uric acid:", round(mean(analytic_data$lbxsua, na.rm=TRUE), 2), "mg/dL\n")

# Define treatment and outcome
Y <- analytic_data$lbxsua
A <- ifelse(analytic_data$bmxwaist >= median(analytic_data$bmxwaist, na.rm=TRUE), 1, 0)
sw <- analytic_data$wtmec2yr

cat("\nTreatment (high waist):", sum(A == 1, na.rm=TRUE), "\n")
cat("Control (low waist):", sum(A == 0, na.rm=TRUE), "\n")

# Covariates
ps_vars <- c("ridageyr", "riagendr", "ridreth1")
if("dmdeduc2" %in% names(analytic_data)) ps_vars <- c(ps_vars, "dmdeduc2")
if("indfmpir" %in% names(analytic_data)) ps_vars <- c(ps_vars, "indfmpir")
if("bmxbmi" %in% names(analytic_data)) ps_vars <- c(ps_vars, "bmxbmi")

cat("\nCovariates:", paste(ps_vars, collapse = ", "), "\n")

# Complete cases
complete_idx <- complete.cases(analytic_data[, c("lbxsua", "bmxwaist", ps_vars, "wtmec2yr")])
data_complete <- analytic_data[complete_idx, ]

cat("\nComplete cases: N =", nrow(data_complete), "\n\n")

# Update vectors
Y <- data_complete$lbxsua
A <- ifelse(data_complete$bmxwaist >= median(data_complete$bmxwaist), 1, 0)
sw <- data_complete$wtmec2yr

X_ps <- as.matrix(data_complete[, ps_vars])
X_pg <- X_ps

results <- list()

# METHOD 1: DSM
cat("--- METHOD 1: Unweighted DSM ---\n")
dsm_result <- dsmatchATE(Y=Y, X=X_ps, A=A, method="dsm", model.ps="logit",
                         model.pg="linpred", lp.pg=X_pg, boots=B_BOOTSTRAP,
                         mc=FALSE, ncpus=1, varest=TRUE)
bootvar_val <- if(is.matrix(dsm_result$bootvar)) dsm_result$bootvar[1,1] else dsm_result$bootvar
results$dsm <- list(estimate=dsm_result$est.ds, 
                    ci=c(dsm_result$est.ds - 1.96*sqrt(bootvar_val),
                         dsm_result$est.ds + 1.96*sqrt(bootvar_val)))
cat("  Done:", round(results$dsm$estimate, 2), "\n\n")

# METHOD 2: PGM
cat("--- METHOD 2: Unweighted PGM ---\n")
pgm_result <- dsmatchATE(Y=Y, X=X_pg, A=A, method="pg", model.pg="glm",
                         boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bootvar_pgm <- if(is.matrix(pgm_result$bootvar)) pgm_result$bootvar[1,1] else pgm_result$bootvar
results$pgm <- list(estimate=pgm_result$est.pg,
                    ci=c(pgm_result$est.pg - 1.96*sqrt(bootvar_pgm),
                         pgm_result$est.pg + 1.96*sqrt(bootvar_pgm)))
cat("  Done:", round(results$pgm$estimate, 2), "\n\n")

# METHOD 3: PSM
cat("--- METHOD 3: Unweighted PSM ---\n")
psm_result <- dsmatchATE(Y=Y, X=X_ps, A=A, method="ps", model.ps="logit",
                         boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bootvar_psm <- if(is.matrix(psm_result$bootvar)) psm_result$bootvar[1,1] else psm_result$bootvar
results$psm <- list(estimate=psm_result$est.ps,
                    ci=c(psm_result$est.ps - 1.96*sqrt(bootvar_psm),
                         psm_result$est.ps + 1.96*sqrt(bootvar_psm)))
cat("  Done:", round(results$psm$estimate, 2), "\n\n")

# METHOD 4: Survey-Weighted PS Full
cat("--- METHOD 4: Survey-Weighted PS Full ---\n")
df_match <- data.frame(Y=Y, A=A, sw=sw, data_complete[, ps_vars])
df_match$sw_norm <- df_match$sw * nrow(df_match) / sum(df_match$sw)

ps_formula <- as.formula(paste("A ~", paste(ps_vars, collapse=" + ")))
m_full <- matchit(ps_formula, data=df_match, method="full", estimand="ATE")
md <- match.data(m_full)
md$sw <- df_match$sw_norm[as.numeric(rownames(md))]

outcome_formula <- as.formula(paste("Y ~ A * (", paste(ps_vars, collapse=" + "), ")"))
fit_full <- lm(outcome_formula, data=md, weights=weights)
ate_full <- avg_comparisons(fit_full, variables="A", vcov=~subclass, wts="sw")

results$ps_full <- list(estimate=ate_full$estimate, ci=c(ate_full$conf.low, ate_full$conf.high))
cat("  Done:", round(results$ps_full$estimate, 2), "\n\n")

# METHOD 5: WDSM
cat("--- METHOD 5: WDSM ---\n")
wdsm_data <- data_complete
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- sw

ps_formula_wdsm <- as.formula(paste("A ~", paste(ps_vars, collapse=" + ")))
pg_formula_wdsm <- as.formula(paste("~", paste(ps_vars, collapse=" + ")))

wdsm_boot <- bootstrap_adaptive_wdsm(data=wdsm_data, ps_formula=ps_formula_wdsm,
                                     pg_formula=pg_formula_wdsm,
                                     outcome_var="Y", treatment_var="A",
                                     weight_var="survey_weight",
                                     n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)

results$wdsm <- list(estimate=wdsm_boot$point_estimate, ci=c(wdsm_boot$ci[1], wdsm_boot$ci[2]))
cat("  Done:", round(results$wdsm$estimate, 2), "\n\n")

# PRESENT RESULTS
cat("═══════════════════════════════════════════════════════════════════════════\n")
cat("ANALYSIS 2: Waist → Uric Acid (N=", nrow(data_complete), ")\n")
cat("═══════════════════════════════════════════════════════════════════════════\n\n")

cat("Method                     Estimate   95% CI            Sig?   Estimand\n")
cat("───────────────────────────────────────────────────────────────────────────\n")

for(m in c('dsm','pgm','psm','ps_full','wdsm')) {
  r <- results[[m]]
  sig <- ifelse(r$ci[1] > 0, 'YES ✓', 'NO')
  estimand <- ifelse(m %in% c('ps_full','wdsm'), 'Population', 'Sample')
  method_name <- c(dsm='Unweighted DSM', pgm='Unweighted PGM',
                   psm='Unweighted PSM', ps_full='Survey-Weighted PS Full',
                   wdsm='WDSM')[m]
  cat(sprintf('%-25s  %6.2f   [%6.2f,%6.2f]   %6s   %s\n',
              method_name, r$estimate, r$ci[1], r$ci[2], sig, estimand))
}

cat('───────────────────────────────────────────────────────────────────────────\n')

sample_avg <- mean(c(results$dsm$estimate, results$pgm$estimate, results$psm$estimate))
pop_avg <- mean(c(results$ps_full$estimate, results$wdsm$estimate))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

cat('Sample avg:', round(sample_avg,2), '| Pop avg:', round(pop_avg,2), 
    '| Bias:', sprintf('%+.1f%%', bias_pct), '\n')

save(data_complete, results, sample_avg, pop_avg, bias_pct,
     file="ANALYSIS_02_WAIST_URIC_COMPLETE.rda")

cat('\n✅ COMPLETE\n')

