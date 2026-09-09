################################################################################
# ANALYSIS 5: Lead Exposure → Creatinine
# STANDALONE SCRIPT - ALL 5 METHODS
#
# Research Question: Does high lead exposure affect kidney function?
# Treatment: High lead (≥median) vs Low lead (<median)
# Outcome: Serum creatinine
# Methods: DSM, PGM, PSM, PS Full, WDSM
################################################################################

rm(list = ls())

library(dplyr)
library(MatchIt)
library(marginaleffects)
library(survey)

if(!require(dsmatch)) {
  install.packages("dsmatch")
  library(dsmatch)
}

source("WDSM_adaptive.R")

set.seed(2024)
B_BOOTSTRAP <- 50

cat('\n===============================================================================\n')
cat('ANALYSIS 5: Lead Exposure → Creatinine\n')
cat('===============================================================================\n\n')

################################################################################
# STEP 1: DATA PREPARATION
################################################################################

cat('STEP 1: Data Preparation\n')
cat('─────────────────────────────────────────────────────────────────────────\n\n')

load("data/nhanes_2007_2018.rda")

# Age restriction 40-70, use lbxapb for lead
data_complete <- nhanes_2007_2018 %>%
  filter(
    !is.na(lbxapb),
    !is.na(lbdscrsi),
    ridageyr >= 40, ridageyr <= 70,
    !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1),
    !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi),
    !is.na(wtmec2yr), wtmec2yr > 0
  )

cat('Sample size: N =', nrow(data_complete), '\n')
cat('Age range: 40-70 years\n\n')

# Define treatment (median split)
lead_median <- median(data_complete$lbxapb, na.rm=TRUE)
Y <- data_complete$lbdscrsi  # Serum creatinine
A <- ifelse(data_complete$lbxapb >= lead_median, 1, 0)
sw <- data_complete$wtmec2yr

cat('Treatment (blood lead):\n')
cat('  Median:', round(lead_median, 2), 'µg/dL\n')
cat('  High lead (≥median):', sum(A==1), '\n')
cat('  Low lead (<median):', sum(A==0), '\n\n')

cat('Outcome (serum creatinine):\n')
cat('  Mean (SD):', round(mean(Y), 2), '(', round(sd(Y), 2), ')\n')
cat('  Range:', round(min(Y), 1), '-', round(max(Y), 1), '\n\n')

# Covariates
covars <- c("ridageyr", "riagendr", "ridreth1", "dmdeduc2", "indfmpir", "bmxbmi")
cat('Covariates:', paste(covars, collapse=", "), '\n\n')

X <- as.matrix(data_complete[, covars])

################################################################################
# STEP 2: ALL 5 MATCHING METHODS
################################################################################

cat('STEP 2: Running All 5 Matching Methods\n')
cat('─────────────────────────────────────────────────────────────────────────\n\n')

results <- list()

# METHOD 1: DSM
cat('Method 1: Unweighted DSM...')
r_dsm <- dsmatchATE(Y=Y, X=X, A=A, method="dsm", model.ps="logit",
                    model.pg="linpred", lp.pg=X, boots=B_BOOTSTRAP,
                    mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(r_dsm$bootvar)) r_dsm$bootvar[1,1] else r_dsm$bootvar
results$dsm <- list(estimate=r_dsm$est.ds, ci=r_dsm$est.ds + c(-1.96,1.96)*sqrt(bv))
cat(' Done\n')

# METHOD 2: PGM
cat('Method 2: Unweighted PGM...')
r_pgm <- dsmatchATE(Y=Y, X=X, A=A, method="pg", model.pg="glm",
                    boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(r_pgm$bootvar)) r_pgm$bootvar[1,1] else r_pgm$bootvar
results$pgm <- list(estimate=r_pgm$est.pg, ci=r_pgm$est.pg + c(-1.96,1.96)*sqrt(bv))
cat(' Done\n')

# METHOD 3: PSM
cat('Method 3: Unweighted PSM...')
r_psm <- dsmatchATE(Y=Y, X=X, A=A, method="ps", model.ps="logit",
                    boots=B_BOOTSTRAP, mc=FALSE, ncpus=1, varest=TRUE)
bv <- if(is.matrix(r_psm$bootvar)) r_psm$bootvar[1,1] else r_psm$bootvar
results$psm <- list(estimate=r_psm$est.ps, ci=r_psm$est.ps + c(-1.96,1.96)*sqrt(bv))
cat(' Done\n')

# METHOD 4: Survey-Weighted PS Full
cat('Method 4: Survey-Weighted PS Full...')
df <- data.frame(Y=Y, A=A, sw=sw, data_complete[, covars])
df$sw_norm <- df$sw * nrow(df) / sum(df$sw)
m <- matchit(as.formula(paste("A ~", paste(covars, collapse=" + "))),
             data=df, method="full", estimand="ATE")
md <- match.data(m)
md$sw <- df$sw_norm[as.numeric(rownames(md))]
fit <- lm(as.formula(paste("Y ~ A * (", paste(covars, collapse=" + "), ")")),
          data=md, weights=weights)
ate <- avg_comparisons(fit, variables="A", vcov=~subclass, wts="sw")
results$ps_full <- list(estimate=as.numeric(ate$estimate),
                        ci=c(as.numeric(ate$conf.low), as.numeric(ate$conf.high)))
cat(' Done\n')

# METHOD 5: WDSM
cat('Method 5: WDSM...')
wdsm_data <- data_complete
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- sw

wdsm_boot <- bootstrap_adaptive_wdsm(
  data=wdsm_data,
  ps_formula=as.formula(paste("A ~", paste(covars, collapse=" + "))),
  pg_formula=as.formula(paste("~", paste(covars, collapse=" + "))),
  outcome_var="Y", treatment_var="A", weight_var="survey_weight",
  n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE
)

results$wdsm <- list(estimate=wdsm_boot$point_estimate$tau,
                     ci=c(wdsm_boot$ci_lower, wdsm_boot$ci_upper))
cat(' Done\n\n')

################################################################################
# STEP 3: RESULTS
################################################################################

sample_avg <- mean(c(results$dsm$estimate, results$pgm$estimate, results$psm$estimate))
pop_avg <- mean(c(results$ps_full$estimate, results$wdsm$estimate))
bias_pct <- (sample_avg - pop_avg) / pop_avg * 100

cat('═══════════════════════════════════════════════════════════════════════════\n')
cat('FINAL RESULTS: Waist → Uric Acid (N=', nrow(data_complete), ')\n')
cat('═══════════════════════════════════════════════════════════════════════════\n\n')

cat('Method                     Estimate   95% CI            Sig?   Estimand\n')
cat('───────────────────────────────────────────────────────────────────────────\n')

for(m in c('dsm','pgm','psm','ps_full','wdsm')) {
  r <- results[[m]]
  sig <- ifelse(r$ci[1]*r$ci[2] > 0, 'YES ✓', 'NO')
  estimand <- ifelse(m %in% c('ps_full','wdsm'), 'Population', 'Sample')
  method_name <- c(dsm='Unweighted DSM', pgm='Unweighted PGM',
                   psm='Unweighted PSM', ps_full='Survey-Weighted PS Full',
                   wdsm='WDSM')[m]
  cat(sprintf('%-25s  %7.3f  [%7.3f,%7.3f]  %6s   %s\n',
              method_name, r$estimate, r$ci[1], r$ci[2], sig, estimand))
}

cat('───────────────────────────────────────────────────────────────────────────\n')
cat('Sample avg:', round(sample_avg,3), '| Pop avg:', round(pop_avg,3),
    '| Bias:', sprintf('%+.1f%%', bias_pct), '\n')

# Save results
save(data_complete, results, sample_avg, pop_avg, bias_pct,
     file="ANALYSIS_02_WAIST_URIC_FINAL.rda")

cat('\n✅ ANALYSIS 2 COMPLETE\n')
cat('Results saved: ANALYSIS_02_WAIST_URIC_FINAL.rda\n')
cat('═══════════════════════════════════════════════════════════════════════════\n')

