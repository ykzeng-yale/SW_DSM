################################################################################
# ANALYSIS 6: Smoking → Triglycerides (FAST VERSION)
# Using simple matching without full dsmatch bootstrap
################################################################################

library(dplyr)
library(MatchIt)
library(marginaleffects)
library(survey)

source("WDSM_adaptive.R")

set.seed(2024)

cat("\n===============================================================================\n")
cat("ANALYSIS 6: Current Smoking → Serum Triglycerides\n")
cat("===============================================================================\n\n")

# Load and prep data
load("data/nhanes_2007_2018.rda")

data_complete <- nhanes_2007_2018 %>%
  mutate(A = case_when(smq020==2~0, smq020==1 & smq040 %in% c(1,2)~1, 
                       smq020==1 & smq040==3~0, TRUE~NA_real_)) %>%
  filter(!is.na(A), !is.na(lbxtr), ridageyr>=20, 
         !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1),
         !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi),
         !is.na(wtmec2yr), wtmec2yr>0)

Y <- data_complete$lbxtr
A <- data_complete$A
sw <- data_complete$wtmec2yr

cat("N =", nrow(data_complete), "| Treated:", sum(A==1), "| Control:", sum(A==0), "\n\n")

# Covariates
covars <- c("ridageyr", "riagendr", "ridreth1", "dmdeduc2", "indfmpir", "bmxbmi")
X <- as.matrix(data_complete[, covars])

# PS and PG models
ps_mod <- glm(A ~ ., data=data.frame(A, X), family=binomial())
pg_mod <- lm(Y ~ ., data=data.frame(Y, X), subset=(A==0))
ps <- predict(ps_mod, type="response")
pg <- predict(pg_mod, newdata=data.frame(X))

# METHOD 1: DSM
m1 <- matchit(A~ps+pg, data=data.frame(A,ps,pg), method="nearest", distance="mahalanobis", ratio=1)
d1 <- match.data(m1); d1$Y <- Y[as.numeric(rownames(d1))]
est1 <- mean(d1$Y[d1$A==1]) - mean(d1$Y[d1$A==0])
se1 <- sqrt(var(d1$Y[d1$A==1])/sum(d1$A==1) + var(d1$Y[d1$A==0])/sum(d1$A==0))

# METHOD 2: PGM
m2 <- matchit(A~pg, data=data.frame(A,pg), method="nearest", ratio=1)
d2 <- match.data(m2); d2$Y <- Y[as.numeric(rownames(d2))]
est2 <- mean(d2$Y[d2$A==1]) - mean(d2$Y[d2$A==0])
se2 <- sqrt(var(d2$Y[d2$A==1])/sum(d2$A==1) + var(d2$Y[d2$A==0])/sum(d2$A==0))

# METHOD 3: PSM
m3 <- matchit(A~ps, data=data.frame(A,ps), method="nearest", ratio=1)
d3 <- match.data(m3); d3$Y <- Y[as.numeric(rownames(d3))]
est3 <- mean(d3$Y[d3$A==1]) - mean(d3$Y[d3$A==0])
se3 <- sqrt(var(d3$Y[d3$A==1])/sum(d3$A==1) + var(d3$Y[d3$A==0])/sum(d3$A==0))

# METHOD 4: Weighted
m4 <- matchit(A~ps, data=data.frame(A,ps), method="subclass", estimand="ATE")
d4 <- match.data(m4)
d4$Y <- Y[as.numeric(rownames(d4))]
d4$sw <- sw[as.numeric(rownames(d4))]
d4$sw_n <- d4$sw * nrow(d4) / sum(d4$sw)
svy4 <- svydesign(ids=~1, weights=~sw_n, data=d4)
fit4 <- svyglm(Y~A, design=svy4)
est4 <- coef(fit4)[2]
ci4 <- confint(fit4)[2,]

# METHOD 5: WDSM
cat("Computing WDSM (50 bootstrap)...\n")
wdsm_data <- data_complete
wdsm_data$Y <- Y
wdsm_data$A <- A
wdsm_data$survey_weight <- sw

ps_formula_wdsm <- as.formula(paste("A ~", paste(covars, collapse=" + ")))
pg_formula_wdsm <- as.formula(paste("~", paste(covars, collapse=" + ")))

wdsm_res <- wdsm_adaptive(data=wdsm_data, ps_formula=ps_formula_wdsm, pg_formula=pg_formula_wdsm,
                          outcome_var="Y", treatment_var="A", weight_var="survey_weight",
                          M=5, use_bias_correction=TRUE, verbose=FALSE)

wdsm_boot <- bootstrap_adaptive_wdsm(data=wdsm_data, ps_formula=ps_formula_wdsm, 
                                     pg_formula=pg_formula_wdsm,
                                     outcome_var="Y", treatment_var="A", 
                                     weight_var="survey_weight",
                                     n_bootstrap=50, M=5, use_bias_correction=TRUE, verbose=FALSE)

results <- list(
  dsm=list(estimate=est1, ci=est1+c(-1.96,1.96)*se1),
  pgm=list(estimate=est2, ci=est2+c(-1.96,1.96)*se2),
  psm=list(estimate=est3, ci=est3+c(-1.96,1.96)*se3),
  ps_full=list(estimate=as.numeric(est4), ci=as.numeric(ci4)),
  wdsm=list(estimate=wdsm_boot$point_estimate, 
            ci=c(wdsm_boot$ci[1], wdsm_boot$ci[2]))
)

sample_avg <- mean(c(est1,est2,est3))
pop_avg <- mean(c(as.numeric(est4), wdsm_boot$point_estimate))
bias_pct <- (sample_avg-pop_avg)/pop_avg*100

save(data_complete, results, sample_avg, pop_avg, bias_pct,
     file="ANALYSIS_06_SMOKING_TRIGLYCERIDES_COMPLETE.rda")

cat("\n===============================================================================\n")
cat("ANALYSIS 6: Smoking → Triglycerides (N=", nrow(data_complete), ")\n")
cat("===============================================================================\n\n")
cat("Method                        Estimate    95% CI                Estimand\n")
cat("──────────────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-28s  %6.2f     [%6.2f, %6.2f]     Sample\n", "Unweighted DSM", est1, results$dsm$ci[1], results$dsm$ci[2]))
cat(sprintf("%-28s  %6.2f     [%6.2f, %6.2f]     Sample\n", "Unweighted PGM", est2, results$pgm$ci[1], results$pgm$ci[2]))
cat(sprintf("%-28s  %6.2f     [%6.2f, %6.2f]     Sample\n", "Unweighted PSM", est3, results$psm$ci[1], results$psm$ci[2]))
cat(sprintf("%-28s  %6.2f     [%6.2f, %6.2f]     Population\n", "Survey-Weighted PS Full", est4, ci4[1], ci4[2]))
cat(sprintf("%-28s  %6.2f     [%6.2f, %6.2f]     Population\n", "WDSM", wdsm_boot$point_estimate, wdsm_boot$ci[1], wdsm_boot$ci[2]))
cat("──────────────────────────────────────────────────────────────────────────\n")
cat("\nEstimates = Triglycerides difference (mg/dL): Smokers vs Non-smokers\n")
cat("Sample avg:", round(sample_avg,2), "| Pop avg:", round(pop_avg,2), "| Bias:", sprintf("%+.1f%%", bias_pct), "\n")
cat("\n✅ COMPLETE\n")

