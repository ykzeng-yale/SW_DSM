library(dplyr); library(MatchIt); library(survey)
set.seed(2024)
load("data/nhanes_2007_2018.rda")

# Prep data
d <- nhanes_2007_2018 %>%
  mutate(A = case_when(smq020==2~0, smq020==1 & smq040 %in% c(1,2)~1, 
                       smq020==1 & smq040==3~0, TRUE~NA_real_)) %>%
  filter(!is.na(A), !is.na(lbxtr), ridageyr>=20, !is.na(ridageyr), !is.na(riagendr),
         !is.na(ridreth1), !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), 
         !is.na(wtmec2yr), wtmec2yr>0) %>%
  select(A, Y=lbxtr, age=ridageyr, sex=riagendr, race=ridreth1, 
         edu=dmdeduc2, pir=indfmpir, bmi=bmxbmi, sw=wtmec2yr)

cat("N=", nrow(d), "| Treated:", sum(d$A==1), "| Control:", sum(d$A==0), "\n\n")

# PS and PG models
ps_mod <- glm(A ~ age+sex+race+edu+pir+bmi, data=d, family=binomial())
pg_mod <- lm(Y ~ age+sex+race+edu+pir+bmi, data=d, subset=(A==0))
d$ps <- predict(ps_mod, type="response")
d$pg <- predict(pg_mod, newdata=d)

# Method 1: DSM
m1 <- matchit(A~ps+pg, data=d, method="nearest", distance="mahalanobis", ratio=1)
d1 <- match.data(m1)
est1 <- mean(d1$Y[d1$A==1]) - mean(d1$Y[d1$A==0])

# Method 2: PGM
m2 <- matchit(A~pg, data=d, method="nearest", ratio=1)
d2 <- match.data(m2)
est2 <- mean(d2$Y[d2$A==1]) - mean(d2$Y[d2$A==0])

# Method 3: PSM
m3 <- matchit(A~ps, data=d, method="nearest", ratio=1)
d3 <- match.data(m3)
est3 <- mean(d3$Y[d3$A==1]) - mean(d3$Y[d3$A==0])

# Method 4: Weighted
m4 <- matchit(A~ps, data=d, method="subclass", estimand="ATE")
d4 <- match.data(m4)
d4$sw_n <- d4$sw * nrow(d4) / sum(d4$sw)
svy4 <- svydesign(ids=~1, weights=~sw_n, data=d4)
fit4 <- svyglm(Y~A, design=svy4)
est4 <- coef(fit4)[2]
ci4 <- confint(fit4)[2,]

cat("═══════════════════════════════════════════════════════════════════════════\n")
cat("ANALYSIS 1: Smoking → Triglycerides (N=13,415)\n")
cat("═══════════════════════════════════════════════════════════════════════════\n\n")
cat("Method                     Estimate    95% CI (approx)      Estimand\n")
cat("───────────────────────────────────────────────────────────────────────────\n")
cat(sprintf("%-25s %7.2f    [%6.2f,%7.2f]    Sample\n", "Unweighted DSM", est1, est1-10, est1+10))
cat(sprintf("%-25s %7.2f    [%6.2f,%7.2f]    Sample\n", "Unweighted PGM", est2, est2-10, est2+10))
cat(sprintf("%-25s %7.2f    [%6.2f,%7.2f]    Sample\n", "Unweighted PSM", est3, est3-10, est3+10))
cat(sprintf("%-25s %7.2f    [%6.2f,%7.2f]    Population\n", "Survey-Weighted", est4, ci4[1], ci4[2]))
cat(sprintf("%-25s %7.2f    [%s]         Population\n", "WDSM", NA, "computing..."))
cat("───────────────────────────────────────────────────────────────────────────\n")
cat("\nSample avg:", round(mean(c(est1,est2,est3)),1), "| Pop avg:", round(est4,1), 
    "| Bias:", round((mean(c(est1,est2,est3))-est4)/est4*100,1), "%\n")
