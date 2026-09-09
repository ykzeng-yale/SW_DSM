################################################################################
# RUN REMAINING 6 ANALYSES (4, 5, 7, 8, 9, 10) WITH M=1, M=3, M=5
################################################################################

library(dplyr)
source("WDSM_adaptive.R")
set.seed(2024)

load("data/nhanes_2007_2018.rda")

# Helper function
run_M_values <- function(num, title, data_prep, Y, A, sw, covars) {
  cat('═══════════════════════════════════════════════════════════════════════════\n')
  cat('ANALYSIS', num, ':', title, '(N=', length(Y), ')\n')
  cat('═══════════════════════════════════════════════════════════════════════════\n')
  
  wdsm_data <- data_prep
  wdsm_data$Y <- Y
  wdsm_data$A <- A
  wdsm_data$survey_weight <- sw
  
  ps_f <- as.formula(paste("A ~", paste(covars, collapse=" + ")))
  pg_f <- as.formula(paste("~", paste(covars, collapse=" + ")))
  
  wdsm_res <- list()
  for(M in c(1,3,5)) {
    cat('M=', M, '...', sep='')
    wb <- bootstrap_adaptive_wdsm(data=wdsm_data, ps_formula=ps_f, pg_formula=pg_f,
                                  outcome_var="Y", treatment_var="A", weight_var="survey_weight",
                                  n_bootstrap=50, M=M, use_bias_correction=TRUE, verbose=FALSE)
    wdsm_res[[paste0("M",M)]] <- list(estimate=wb$point_estimate$tau, ci_lower=wb$ci_lower, ci_upper=wb$ci_upper)
    cat(' Done\n')
  }
  
  save(data_prep, wdsm_res, file=paste0("WDSM_M1_M3_M5_ANALYSIS_", sprintf("%02d",num), ".rda"))
  cat('Saved\n\n')
  wdsm_res
}

# Analysis 4
d4 <- nhanes_2007_2018 %>% filter(!is.na(paq650), !is.na(lbxgh), ridageyr>=40, ridageyr<=70, !is.na(diq010), diq010!=1,
                                  !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1), !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), !is.na(wtmec2yr))
run_M_values(4, "MVPA→HbA1c", d4, d4$lbxgh, ifelse(d4$paq650==1,1,0), d4$wtmec2yr,
            c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi"))

# Analysis 5
d5 <- nhanes_2007_2018 %>% filter(!is.na(lbxapb), !is.na(lbdscrsi), ridageyr>=40, ridageyr<=70,
                                  !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1), !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), !is.na(wtmec2yr))
run_M_values(5, "Lead→Creatinine", d5, d5$lbdscrsi, ifelse(d5$lbxapb>=median(d5$lbxapb,na.rm=TRUE),1,0), d5$wtmec2yr,
            c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi"))

# Analysis 7
d7 <- nhanes_2007_2018 %>% filter(!is.na(paq605), !is.na(bpxsy1), ridageyr>=40, ridageyr<=70,
                                  !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1), !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), !is.na(wtmec2yr))
run_M_values(7, "PA→SBP", d7, d7$bpxsy1, ifelse(d7$paq605==1,1,0), d7$wtmec2yr,
            c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi"))

# Analysis 8
d8 <- nhanes_2007_2018 %>% filter(!is.na(bmxbmi), !is.na(lbxsatsi), ridageyr>=40, ridageyr<=70, lbxsatsi>0, lbxsatsi<300,
                                  !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1), !is.na(dmdeduc2), !is.na(indfmpir), !is.na(wtmec2yr))
run_M_values(8, "Obesity→ALT", d8, d8$lbxsatsi, ifelse(d8$bmxbmi>=30,1,0), d8$wtmec2yr,
            c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir"))

# Analysis 9
d9 <- nhanes_2007_2018 %>% filter(!is.na(alq130), !is.na(lbdhdd), ridageyr>=40, ridageyr<=70,
                                  !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1), !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), !is.na(wtmec2yr))
run_M_values(9, "Alcohol→HDL", d9, d9$lbdhdd, ifelse(d9$alq130>=median(d9$alq130,na.rm=TRUE),1,0), d9$wtmec2yr,
            c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi"))

# Analysis 10
d10 <- nhanes_2007_2018 %>% filter(!is.na(sld012), !is.na(lbxgh), ridageyr>=40, ridageyr<=70, !is.na(diq010), diq010!=1,
                                   !is.na(ridageyr), !is.na(riagendr), !is.na(ridreth1), !is.na(dmdeduc2), !is.na(indfmpir), !is.na(bmxbmi), !is.na(wtmec2yr))
run_M_values(10, "Sleep→HbA1c", d10, d10$lbxgh, ifelse(d10$sld012<7,1,0), d10$wtmec2yr,
            c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi"))

cat('✅ ALL 6 REMAINING ANALYSES COMPLETE\n')








