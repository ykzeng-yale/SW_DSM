#!/usr/bin/env Rscript

#' Complete all 10 questions with FULL DATA - Final corrected version

suppressPackageStartupMessages({library(tidyverse); library(survey); library(MatchIt); library(marginaleffects); library(Matching)})
invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")
load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

run5 <- function(Y,A,X,w,d,ps_f,pgs_f,tcol,B=50){
  r <- list()
  cat("WDSM...")
  set.seed(2025)
  tryCatch({wdsm<-wdsm_flexible(d%>%mutate(Y=Y,Treatment=A),"Y","Treatment",ps_f,pgs_f,"w",M=5,B=B,verbose=FALSE);r$wdsm<-wdsm;cat("✓ ")},error=function(e){r$wdsm<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("✗ ")})
  cat("DSM...")
  set.seed(2025)
  tryCatch({dsm<-dsmatchATE(Y=Y,X=X,A=A,method="dsm",model.ps="logit",model.pg="linpred",lp.pg=X,varest=TRUE,boots=B,cov.balance=FALSE,mc=FALSE);r$dsm<-list(estimate=dsm$est.ds,se=sqrt(dsm$bootvar[1,1]),ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]),ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]));cat("✓ ")},error=function(e){r$dsm<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("✗ ")})
  cat("PSM...")
  set.seed(2025)
  tryCatch({psm<-dsmatchATE(Y=Y,X=X,A=A,method="ps",model.ps="logit",varest=TRUE,boots=B,cov.balance=FALSE,mc=FALSE);r$psm<-list(estimate=psm$est.ps,se=sqrt(psm$bootvar[1,1]),ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]),ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]));cat("✓ ")},error=function(e){r$psm<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("✗ ")})
  cat("PGM...")
  set.seed(2025)
  tryCatch({pgm<-dsmatchATE(Y=Y,X=X,A=A,method="pg",model.pg="linpred",lp.pg=X,varest=TRUE,boots=B,cov.balance=FALSE,mc=FALSE);r$pgm<-list(estimate=pgm$est.pg,se=sqrt(pgm$bootvar[1,1]),ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]),ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]));cat("✓ ")},error=function(e){r$pgm<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("✗ ")})
  cat("PSF...")
  set.seed(2025)
  tryCatch({d$sw<-d$w*nrow(d)/sum(d$w);m<-matchit(ps_f,data=d,method="full",estimand="ATE",s.weights=d$sw);md<-match.data(m);md$Y<-Y[as.numeric(rownames(md))];md$Treatment<-md[[tcol]];md$weights<-md$sw*md$weights;cov_names<-all.vars(ps_f)[-1];formula_str<-paste("Y ~ Treatment * (",paste(cov_names,collapse=" + "),")");fit<-lm(as.formula(formula_str),data=md,weights=weights);ate<-avg_comparisons(fit,variables="Treatment",vcov=~subclass,wts="sw");r$ps_full<-list(estimate=ate$estimate[1],se=ate$std.error[1],ci_lower=ate$conf.low[1],ci_upper=ate$conf.high[1]);cat("✓\n")},error=function(e){r$ps_full<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("✗\n")})
  return(r)
}

ar <- list()
cat("\n=== RUNNING ALL 10 WITH FULL DATA (B=50) ===\n\n")

# Q1
cat("Q1...")
d1<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365)%>%mutate(alcohol_days=as.numeric(ALCDAYS),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),w=ANALWT2_C1)%>%filter(!is.na(female),!is.na(w))
Y<-d1$alcohol_days;A<-d1$female;X<-as.matrix(d1[,c("age_older","black","hispanic","college","unemployed")])
ps_f<-as.formula("A~age_older+black+hispanic+college+unemployed");pgs_f<-as.formula("Y~age_older+black+hispanic+college+unemployed")
ar$q1<-run5(Y,A,X,d1$w,d1,ps_f,pgs_f,"female",50)

# Q2
cat("Q2...")
d2<-data%>%filter(YEAR==2023,MJDAY30A>=1,MJDAY30A<=30)%>%mutate(marijuana_days=as.numeric(MJDAY30A),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),w=ANALWT2_C1)%>%filter(!is.na(female),!is.na(w))
Y<-d2$marijuana_days;A<-d2$female;X<-as.matrix(d2[,c("age_older","black","hispanic","college","unemployed")])
ar$q2<-run5(Y,A,X,d2$w,d2,ps_f,pgs_f,"female",50)

# Q3
cat("Q3...")
d3<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365,CATAGE>=2,CATAGE<=5)%>%mutate(alcohol_days=as.numeric(ALCDAYS),unemployed=case_when(IRWRKSTAT18==3~1,IRWRKSTAT18==1~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(unemployed),!is.na(w))
Y<-d3$alcohol_days;A<-d3$unemployed;X<-as.matrix(d3[,c("female","age_older","black","hispanic","college","poverty_low")])
ps_f3<-as.formula("A~female+age_older+black+hispanic+college+poverty_low");pgs_f3<-as.formula("Y~female+age_older+black+hispanic+college+poverty_low")
ar$q3<-run5(Y,A,X,d3$w,d3,ps_f3,pgs_f3,"unemployed",50)

# Q4
cat("Q4...")
d4<-data%>%filter(YEAR==2023,MJDAY30A>=1,MJDAY30A<=30)%>%mutate(marijuana_days=as.numeric(MJDAY30A),young=case_when(CATAGE==2~1,CATAGE>=3~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(young),!is.na(w))
Y<-d4$marijuana_days;A<-d4$young;X<-as.matrix(d4[,c("female","black","hispanic","college","unemployed","poverty_low")])
ps_f4<-as.formula("A~female+black+hispanic+college+unemployed+poverty_low");pgs_f4<-as.formula("Y~female+black+hispanic+college+unemployed+poverty_low")
ar$q4<-run5(Y,A,X,d4$w,d4,ps_f4,pgs_f4,"young",50)

# Q5
cat("Q5...")
d5<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365,CATAGE>=3)%>%mutate(alcohol_days=as.numeric(ALCDAYS),college=case_when(EDUHIGHCAT==4~1,EDUHIGHCAT==2~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=11,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(college),!is.na(w))
Y<-d5$alcohol_days;A<-d5$college;X<-as.matrix(d5[,c("female","age_older","black","hispanic","unemployed","poverty_low")])
ar$q5<-run5(Y,A,X,d5$w,d5,ps_f3,pgs_f3,"college",50)

# Q7
cat("Q7...")
d7<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365)%>%mutate(alcohol_days=as.numeric(ALCDAYS),black=case_when(NEWRACE2==2~1,NEWRACE2==1~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(black),!is.na(w))
Y<-d7$alcohol_days;A<-d7$black;X<-as.matrix(d7[,c("female","age_older","college","unemployed","poverty_low")])
ps_f7<-as.formula("A~female+age_older+college+unemployed+poverty_low");pgs_f7<-as.formula("Y~female+age_older+college+unemployed+poverty_low")
ar$q7<-run5(Y,A,X,d7$w,d7,ps_f7,pgs_f7,"black",50)

# Q10
cat("Q10...")
d10<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365)%>%mutate(alcohol_days=as.numeric(ALCDAYS),hispanic=case_when(NEWRACE2==7~1,NEWRACE2==1~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(hispanic),!is.na(w))
Y<-d10$alcohol_days;A<-d10$hispanic;X<-as.matrix(d10[,c("female","age_older","college","unemployed","poverty_low")])
ar$q10<-run5(Y,A,X,d10$w,d10,ps_f7,pgs_f7,"hispanic",50)

# Q11
cat("Q11...")
d11<-data%>%filter(YEAR==2023,BNGDRMDAYS>=1,BNGDRMDAYS<=30)%>%mutate(binge_days=as.numeric(BNGDRMDAYS),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),w=ANALWT2_C1)%>%filter(!is.na(female),!is.na(w))
Y<-d11$binge_days;A<-d11$female;X<-as.matrix(d11[,c("age_older","black","hispanic","college","unemployed")])
ar$q11<-run5(Y,A,X,d11$w,d11,ps_f,pgs_f,"female",50)

# Q12
cat("Q12...")
d12<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365)%>%mutate(alcohol_days=as.numeric(ALCDAYS),urban=case_when(COUTYP4==1~1,COUTYP4==3~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(urban),!is.na(w))
Y<-d12$alcohol_days;A<-d12$urban;X<-as.matrix(d12[,c("female","age_older","black","hispanic","college","unemployed","poverty_low")])
ps_f12<-as.formula("A~female+age_older+black+hispanic+college+unemployed+poverty_low");pgs_f12<-as.formula("Y~female+age_older+black+hispanic+college+unemployed+poverty_low")
ar$q12<-run5(Y,A,X,d12$w,d12,ps_f12,pgs_f12,"urban",50)

# Q13
cat("Q13...")
d13<-data%>%filter(YEAR==2023,MJDAY30A>=1,MJDAY30A<=30)%>%mutate(marijuana_days=as.numeric(MJDAY30A),high_income=case_when(IRFAMIN3>=5~1,IRFAMIN3<=2~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),w=ANALWT2_C1)%>%filter(!is.na(high_income),!is.na(w))
Y<-d13$marijuana_days;A<-d13$high_income;X<-as.matrix(d13[,c("female","age_older","black","hispanic","college","unemployed")])
ps_f13<-as.formula("A~female+age_older+black+hispanic+college+unemployed");pgs_f13<-as.formula("Y~female+age_older+black+hispanic+college+unemployed")
ar$q13<-run5(Y,A,X,d13$w,d13,ps_f13,pgs_f13,"high_income",50)

saveRDS(ar,"Analysis/Results/ALL_10_FULL_DATA_B50.rds")
cat("\n✓ ALL 10 SAVED\n")

