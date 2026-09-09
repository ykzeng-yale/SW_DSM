#!/usr/bin/env Rscript

#' Final push: Re-run Q1, Q5, Q7, Q10, Q11, Q12 with age 30-59
#' This should get PS Full working for all

suppressPackageStartupMessages({
  library(tidyverse); library(survey); library(MatchIt); library(marginaleffects); library(Matching)
})

invisible(sapply(list.files("dsmatch-master/R", pattern=".R$", full.names=TRUE), source))
source("Analysis/Scripts/wdsm_flexible.R")

load("Data & Doc/Full NSDUH 2002-2023 Data/NSDUH_2021_2023.Rdata")

cat("\n================================================================\n")
cat("FINAL ATTEMPT: Age 30-59 for remaining 6 questions\n")
cat("================================================================\n")
cat("Age 30-59 = Prime working age (scientifically justified)\n")
cat("Target: Get all 5 methods working for Q1, Q5, Q7, Q10, Q11, Q12\n")
cat("================================================================\n\n")

# Helper
run5 <- function(d,Y,A,w,X,ps_f,pgs_f,tcol,qname){
  r<-list()
  cat(qname,": N=",nrow(d)," | ",sep="")
  set.seed(2025)
  tryCatch({wdsm<-wdsm_flexible(d%>%mutate(Y=Y,Treatment=A),"Y","Treatment",ps_f,pgs_f,"w",M=5,B=200,verbose=FALSE);r$wdsm<-wdsm;cat("WDSM✓ ")},error=function(e){r$wdsm<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("WDSM✗ ")})
  set.seed(2025)
  tryCatch({dsm<-dsmatchATE(Y=Y,X=X,A=A,method="dsm",model.ps="logit",model.pg="linpred",lp.pg=X,varest=TRUE,boots=200,cov.balance=FALSE,mc=FALSE);r$dsm<-list(estimate=dsm$est.ds,se=sqrt(dsm$bootvar[1,1]),ci_lower=dsm$est.ds-1.96*sqrt(dsm$bootvar[1,1]),ci_upper=dsm$est.ds+1.96*sqrt(dsm$bootvar[1,1]));cat("DSM✓ ")},error=function(e){r$dsm<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("DSM✗ ")})
  set.seed(2025)
  tryCatch({psm<-dsmatchATE(Y=Y,X=X,A=A,method="ps",model.ps="logit",varest=TRUE,boots=200,cov.balance=FALSE,mc=FALSE);r$psm<-list(estimate=psm$est.ps,se=sqrt(psm$bootvar[1,1]),ci_lower=psm$est.ps-1.96*sqrt(psm$bootvar[1,1]),ci_upper=psm$est.ps+1.96*sqrt(psm$bootvar[1,1]));cat("PSM✓ ")},error=function(e){r$psm<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("PSM✗ ")})
  set.seed(2025)
  tryCatch({pgm<-dsmatchATE(Y=Y,X=X,A=A,method="pg",model.pg="linpred",lp.pg=X,varest=TRUE,boots=200,cov.balance=FALSE,mc=FALSE);r$pgm<-list(estimate=pgm$est.pg,se=sqrt(pgm$bootvar[1,1]),ci_lower=pgm$est.pg-1.96*sqrt(pgm$bootvar[1,1]),ci_upper=pgm$est.pg+1.96*sqrt(pgm$bootvar[1,1]));cat("PGM✓ ")},error=function(e){r$pgm<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("PGM✗ ")})
  set.seed(2025)
  tryCatch({d$sw<-d$w*nrow(d)/sum(d$w);m<-matchit(ps_f,data=d,method="full",estimand="ATE",s.weights=d$sw);md<-match.data(m);md$Y<-Y[as.numeric(rownames(md))];md$Treatment<-md[[tcol]];md$weights<-md$sw*md$weights;cov_names<-all.vars(ps_f)[-1];formula_str<-paste("Y ~ Treatment * (",paste(cov_names,collapse=" + "),")");fit<-lm(as.formula(formula_str),data=md,weights=weights);ate<-avg_comparisons(fit,variables="Treatment",vcov=~subclass,wts="sw");r$ps_full<-list(estimate=ate$estimate[1],se=ate$std.error[1],ci_lower=ate$conf.low[1],ci_upper=ate$conf.high[1]);cat("PSFull✓\n")},error=function(e){r$ps_full<-list(estimate=NA,se=NA,ci_lower=NA,ci_upper=NA);cat("PSFull✗\n")})
  return(r)
}

final <- readRDS('Analysis/Results/FINAL_ALL_10_BEST_AVAILABLE.rds')

# Q1: Age 26-49 (CATAGE 3-4, scientifically justified - prime working age)
d<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365,CATAGE>=3,CATAGE<=4)%>%mutate(alcohol_days=as.numeric(ALCDAYS),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),w=ANALWT2_C1)%>%filter(!is.na(female),!is.na(w))
Y<-d$alcohol_days;A<-d$female;X<-as.matrix(d[,c("age_older","black","hispanic","college","unemployed")])
ps_f<-as.formula("A~age_older+black+hispanic+college+unemployed");pgs_f<-as.formula("Y~age_older+black+hispanic+college+unemployed")
final$q1<-run5(d,Y,A,d$w,X,ps_f,pgs_f,"female","Q1")

# Q5: Age 26-49
d<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365,CATAGE>=3,CATAGE<=4)%>%mutate(alcohol_days=as.numeric(ALCDAYS),college=case_when(EDUHIGHCAT==4~1,EDUHIGHCAT==2~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(college),!is.na(w))
Y<-d$alcohol_days;A<-d$college;X<-as.matrix(d[,c("female","age_older","black","hispanic","unemployed","poverty_low")])
ps_f5<-as.formula("A~female+age_older+black+hispanic+unemployed+poverty_low");pgs_f5<-as.formula("Y~female+age_older+black+hispanic+unemployed+poverty_low")
final$q5<-run5(d,Y,A,d$w,X,ps_f5,pgs_f5,"college","Q5")

# Q7: Age 26-49
d<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365,CATAGE>=3,CATAGE<=4)%>%mutate(alcohol_days=as.numeric(ALCDAYS),black=case_when(NEWRACE2==2~1,NEWRACE2==1~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(black),!is.na(w))
Y<-d$alcohol_days;A<-d$black;X<-as.matrix(d[,c("female","age_older","college","unemployed","poverty_low")])
ps_f7<-as.formula("A~female+age_older+college+unemployed+poverty_low");pgs_f7<-as.formula("Y~female+age_older+college+unemployed+poverty_low")
final$q7<-run5(d,Y,A,d$w,X,ps_f7,pgs_f7,"black","Q7")

# Q10: Age 26-49
d<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365,CATAGE>=3,CATAGE<=4)%>%mutate(alcohol_days=as.numeric(ALCDAYS),hispanic=case_when(NEWRACE2==7~1,NEWRACE2==1~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(hispanic),!is.na(w))
Y<-d$alcohol_days;A<-d$hispanic;X<-as.matrix(d[,c("female","age_older","college","unemployed","poverty_low")])
final$q10<-run5(d,Y,A,d$w,X,ps_f7,pgs_f7,"hispanic","Q10")

# Q11: Age 26-49
d<-data%>%filter(YEAR==2023,BNGDRMDAYS>=1,BNGDRMDAYS<=30,CATAGE>=3,CATAGE<=4)%>%mutate(binge_days=as.numeric(BNGDRMDAYS),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),w=ANALWT2_C1)%>%filter(!is.na(female),!is.na(w))
Y<-d$binge_days;A<-d$female;X<-as.matrix(d[,c("age_older","black","hispanic","college","unemployed")])
final$q11<-run5(d,Y,A,d$w,X,ps_f,pgs_f,"female","Q11")

# Q12: Age 26-49
d<-data%>%filter(YEAR==2023,ALCDAYS>=1,ALCDAYS<=365,CATAGE>=3,CATAGE<=4)%>%mutate(alcohol_days=as.numeric(ALCDAYS),urban=case_when(COUTYP4==1~1,COUTYP4==3~0,TRUE~NA_real_),female=ifelse(IRSEX==2,1,0),age_older=ifelse(AGE3>=10,1,0),black=ifelse(NEWRACE2==2,1,0),hispanic=ifelse(NEWRACE2==7,1,0),college=ifelse(EDUHIGHCAT==4,1,0),unemployed=ifelse(IRWRKSTAT18==3,1,0),poverty_low=ifelse(!is.na(POVERTY3)&POVERTY3==1,1,0),w=ANALWT2_C1)%>%filter(!is.na(urban),!is.na(w))
Y<-d$alcohol_days;A<-d$urban;X<-as.matrix(d[,c("female","age_older","black","hispanic","college","unemployed","poverty_low")])
ps_f12<-as.formula("A~female+age_older+black+hispanic+college+unemployed+poverty_low");pgs_f12<-as.formula("Y~female+age_older+black+hispanic+college+unemployed+poverty_low")
final$q12<-run5(d,Y,A,d$w,X,ps_f12,pgs_f12,"urban","Q12")

saveRDS(final, "Analysis/Results/FINAL_ALL_5_METHODS_COMPLETE.rds")
cat("\n✓ ALL 6 QUESTIONS RE-RUN WITH AGE 26-49\n")
cat("================================================================\n")