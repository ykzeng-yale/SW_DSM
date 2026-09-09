################################################################################
# ANALYSIS 3: Obesity → Systolic Blood Pressure
# ALL 5 METHODS (Following Lin 2024 template)
################################################################################

rm(list = ls())
library(dplyr); library(MatchIt); library(marginaleffects); library(survey)
if (!require(dsmatch)) { install.packages("dsmatch"); library(dsmatch) }
source("WDSM_adaptive.R")

set.seed(2024)
B_BOOTSTRAP <- 50

cat("\n===============================================================================\n")
cat("   ANALYSIS 3: Obesity → Systolic Blood Pressure\n")
cat("===============================================================================\n\n")

load("data/nhanes_2007_2018.rda")

analytic_data <- nhanes_2007_2018 %>%
  filter(!is.na(bmxbmi), !is.na(bpxsy1), ridageyr >= 40 & ridageyr <= 70)  # Age restriction

cat("Sample: N =", nrow(analytic_data), "\n")

Y <- analytic_data$bpxsy1
A <- ifelse(analytic_data$bmxbmi >= 30, 1, 0)  # Obese vs non-obese
sw <- analytic_data$wtmec2yr

cat("Obese (BMI≥30):", sum(A==1, na.rm=TRUE), "| Non-obese:", sum(A==0, na.rm=TRUE), "\n")

ps_vars <- c("ridageyr", "riagendr", "ridreth1")
if("dmdeduc2" %in% names(analytic_data)) ps_vars <- c(ps_vars, "dmdeduc2")
if("indfmpir" %in% names(analytic_data)) ps_vars <- c(ps_vars, "indfmpir")

complete_idx <- complete.cases(analytic_data[, c("bpxsy1", "bmxbmi", ps_vars, "wtmec2yr")])
data_complete <- analytic_data[complete_idx, ]

Y <- data_complete$bpxsy1
A <- ifelse(data_complete$bmxbmi >= 30, 1, 0)
sw <- data_complete$wtmec2yr
X_ps <- as.matrix(data_complete[, ps_vars])
X_pg <- X_ps

cat("Complete cases: N =", nrow(data_complete), "\n\n")

results <- list()

# METHOD 1: DSM
cat("Method 1: DSM...")
dsm_r <- dsmatchATE(Y=Y, X=X_ps, A=A, method="dsm", model.ps="logit",
                    model.pg="linpred", lp.pg=X_pg, boots=B_BOOTSTRAP, 
                    mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(dsm_r$bootvar)) dsm_r$bootvar[1,1] else dsm_r$bootvar
results$dsm <- list(estimate=dsm_r$est.ds, ci=dsm_r$est.ds + c(-1.96,1.96)*sqrt(bv))
cat(" Done\n")

# METHOD 2: PGM
cat("Method 2: PGM...")
pgm_r <- dsmatchATE(Y=Y, X=X_pg, A=A, method="pg", model.pg="glm",
                    boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(pgm_r$bootvar)) pgm_r$bootvar[1,1] else pgm_r$bootvar
results$pgm <- list(estimate=pgm_r$est.pg, ci=pgm_r$est.pg + c(-1.96,1.96)*sqrt(bv))
cat(" Done\n")

# METHOD 3: PSM
cat("Method 3: PSM...")
psm_r <- dsmatchATE(Y=Y, X=X_ps, A=A, method="ps", model.ps="logit",
                    boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(psm_r$bootvar)) psm_r$bootvar[1,1] else psm_r$bootvar
results$psm <- list(estimate=psm_r$est.ps, ci=psm_r$est.ps + c(-1.96,1.96)*sqrt(bv))
cat(" Done\n")

# METHOD 4: Weighted
cat("Method 4: Weighted...")
df <- data.frame(Y=Y, A=A, sw=sw, data_complete[, ps_vars])
df$sw_norm <- df$sw * nrow(df) / sum(df$sw)
ps_formula <- as.formula(paste("A ~", paste(ps_vars, collapse=" + ")))
m <- matchit(ps_formula, data=df, method="full", estimand="ATE")
md <- match.data(m)
md$sw <- df$sw_norm[as.numeric(rownames(md))]
outcome_formula <- as.formula(paste("Y ~ A * (", paste(ps_vars, collapse=" + "), ")"))
fit <- lm(outcome_formula, data=md, weights=weights)
ate <- avg_comparisons(fit, variables="A", vcov=~subclass, wts="sw")
results$ps_full <- list(estimate=ate$estimate, ci=c(ate$conf.low, ate$conf.high))
cat(" Done\n")

# METHOD 5: WDSM
cat("Method 5: WDSM...")
wdsm_data <- data_complete
wdsm_data$Y <- Y; wdsm_data$A <- A; wdsm_data$survey_weight <- sw
ps_f <- as.formula(paste("A ~", paste(ps_vars, collapse=" + ")))
pg_f <- as.formula(paste("~", paste(ps_vars, collapse=" + ")))
wdsm_boot <- bootstrap_adaptive_wdsm(data=wdsm_data, ps_formula=ps_f, pg_formula=pg_f,
                                     outcome_var="Y", treatment_var="A", weight_var="survey_weight",
                                     n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)
results$wdsm <- list(estimate=wdsm_boot$point_estimate, ci=c(wdsm_boot$ci[1], wdsm_boot$ci[2]))
cat(" Done\n\n")

sample_avg <- mean(c(results$dsm$estimate, results$pgm$estimate, results$psm$estimate))
pop_avg <- mean(c(results$ps_full$estimate, results$wdsm$estimate))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

save(data_complete, results, sample_avg, pop_avg, bias_pct,
     file="ANALYSIS_03_OBESITY_SBP_COMPLETE.rda")

cat("═══════════════════════════════════════════════════════════════════════════\n")
cat("ANALYSIS 3: Obesity → SBP (N=", nrow(data_complete), ")\n")
cat("═══════════════════════════════════════════════════════════════════════════\n\n")
cat("Method                     Estimate   95% CI            Sig?   Estimand\n")
cat("───────────────────────────────────────────────────────────────────────────\n")
for(m in c('dsm','pgm','psm','ps_full','wdsm')) {
  r <- results[[m]]
  sig <- ifelse(r$ci[1] > 0, 'YES ✓', 'NO')
  est <- ifelse(m %in% c('ps_full','wdsm'), 'Population', 'Sample')
  nm <- c(dsm='Unweighted DSM', pgm='Unweighted PGM', psm='Unweighted PSM',
          ps_full='Survey-Weighted PS Full', wdsm='WDSM')[m]
  cat(sprintf('%-25s  %6.2f   [%6.2f,%6.2f]   %6s   %s\n',
              nm, r$estimate, r$ci[1], r$ci[2], sig, est))
}
cat("───────────────────────────────────────────────────────────────────────────\n")
cat("Sample avg:", round(sample_avg,2), "| Pop avg:", round(pop_avg,2), 
    "| Bias:", sprintf("%+.1f%%", bias_pct), "\n")
cat("\n✅ COMPLETE\n")

