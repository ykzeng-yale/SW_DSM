#!/usr/bin/env Rscript
# Tasks 0:4 primary WDSM; 5:9 old sample/row-order controls;
# 10:12 cleaned NHANES/row-order controls; 13:15 all comparator methods.
options(warn=2)
repo <- normalizePath(Sys.getenv("WDSM_REPO",getwd()),mustWork=TRUE)
output <- Sys.getenv("CASE_OUTPUT_DIR")
task <- as.integer(Sys.getenv("CASE_TASK_ID",Sys.getenv("SLURM_ARRAY_TASK_ID")))
commit <- Sys.getenv("WDSM_CODE_COMMIT")
stopifnot(nzchar(output),length(task)==1L,!is.na(task),task %in% 0:15,
  grepl("^[0-9a-f]{40}$",commit))
dir.create(output,recursive=TRUE,showWarnings=FALSE)
destination <- file.path(output,sprintf("task_%02d.rds",task))
if(file.exists(destination))stop("Refusing to overwrite: ",destination)
RNGkind("Mersenne-Twister","Inversion","Rejection")
source(file.path(repo,"CaseStudy","case_rerun_config.R"))
source(file.path(repo,"CaseStudy","NSDUH","prepare_nsduh.R"))
source(file.path(repo,"R","comparators_final.R"))
source(file.path(repo,"CaseStudy","comparators_from_raw.R"))
index <- if(task<10L) task%%5L else if(task<13L) task-10L else task-13L
study <- if(task<13L) if(index<3L)"NHANES" else "NSDUH" else if(index==0L)"NHANES" else "NSDUH"
outcome <- if(study=="NHANES")"HbA1c" else if(task<13L) c("AMIPY","SMIPY")[index-2L] else c("AMIPY","SMIPY")[index]
M <- if(study=="NHANES" && task<13L)c(1L,3L,5L)[index+1L] else 5L
variant <- if(task<5L || task>=13L) "corrected" else if(task<10L)"legacy_row_order" else "cleaned_row_order"
prepared <- file.path(repo,"CaseStudy","data_preparation_20260917")
if(study=="NHANES") {
  vars <- case_rerun_config$nhanes_input$variables
  input <- if(variant=="legacy_row_order") file.path(repo,"CaseStudy","NHANES","data","WDSM_M1_M3_M5_ANALYSIS_10.rda") else file.path(prepared,"nhanes_clean_3790.rds")
  if(variant=="legacy_row_order") {
    saved<-new.env();load(input,saved);d<-as.data.frame(saved$data_prep)
    d$Y<-d$lbxgh;d$A<-as.numeric(d$sld012<7);d$survey_weight<-d$wtmec2yr
  } else d<-readRDS(input)
  stopifnot(nrow(d)==if(variant=="legacy_row_order")3793L else 3790L,sum(d$A)==1002L)
} else {
  input<-file.path(prepared,"nsduh_rebuilt_17471.rds")
  Sys.setenv(NSDUH_INPUT=input)
  prep<-nsduh_prepare_data(repo);d<-prep$data;vars<-prep$covariates
  d$Y<-d[[outcome]];d$survey_weight<-d$ANALWT2_C
  stopifnot(nrow(d)==17471L,sum(d$A)==1877L,length(unique(do.call(paste,d[vars])))==1276L)
}
stopifnot(all(complete.cases(d[,c("Y","A","survey_weight",vars)])))
source_files<-c("CaseStudy/rerun_tie_correction.R","CaseStudy/comparators_from_raw.R",
  "CaseStudy/prepare_from_raw.R","CaseStudy/case_rerun_config.R","CaseStudy/NSDUH/prepare_nsduh.R",
  "CaseStudy/NHANES/WDSM_adaptive.R","CaseStudy/NSDUH/wdsm_flexible.R","R/wdsm_ties.R","R/comparators_final.R",
  list.files(file.path(repo,"R","dsmatch"),pattern="\\.R$",full.names=FALSE))
source_files[!grepl("/",source_files)]<-paste0("R/dsmatch/",source_files[!grepl("/",source_files)])
manifest<-list(commit=commit,task=task,study=study,outcome=outcome,M=M,variant=variant,
  B=200L,n=nrow(d),n_treated=sum(d$A),input_md5=unname(tools::md5sum(input)),
  source_md5=setNames(tools::md5sum(file.path(repo,source_files)),source_files),
  tie_seed=20260917L+M,tie_rule=if(variant=="corrected")"random" else "row_order",
  bootstrap_seed_protocol="2024; original NHANES M-specific states advanced on legacy sample sizes",
  job_id=Sys.getenv("SLURM_JOB_ID"),started_utc=format(Sys.time(),tz="UTC",usetz=TRUE))
result <- tryCatch({
  set.seed(2024)
  if(task<13L) {
    if(study=="NHANES") {
      for(n0 in case_rerun_config$nhanes_input$prior_sample_sizes)
        for(b in seq_len(150L))invisible(rmultinom(1L,n0,rep(1/n0,n0)))
      for(previous_M in seq_len(index))
        for(b in seq_len(50L))invisible(rmultinom(1L,3793L,rep(1/3793L,3793L)))
    }
    manifest$seed_start<-.Random.seed
    case<-new.env()
    if(study=="NHANES") {
      sys.source(file.path(repo,"CaseStudy","NHANES","WDSM_adaptive.R"),case)
      fit<-case$bootstrap_adaptive_wdsm(d,reformulate(vars,"A"),reformulate(vars),M=M,
        n_bootstrap=200L,seed=NULL,sampling_design="retrospective",tie_seed=manifest$tie_seed,tie_rule=manifest$tie_rule)
      estimate<-fit$point_estimate$tau
      identity_error<-fit$point_estimate$identity_error
    } else {
      sys.source(file.path(repo,"CaseStudy","NSDUH","wdsm_flexible.R"),case)
      fit<-case$wdsm_flexible(d,"Y","A",prep$ps_formula,prep$pgs_formula,"ANALWT2_C",
        M=M,B=200L,verbose=FALSE,tie_seed=manifest$tie_seed,tie_rule=manifest$tie_rule)
      estimate<-fit$estimate;identity_error<-fit$identity_error
    }
    draws<-fit$bootstrap_estimates
    se<-sqrt(mean((draws-mean(draws))^2));ci<-estimate+c(-1,1)*qnorm(.975)*se
    stopifnot(length(draws)==200L,all(is.finite(draws)),identity_error<1e-9,
      abs(fit$se-se)<1e-12,max(abs(c(fit$ci_lower,fit$ci_upper)-ci))<1e-12)
    ps<-c(list(fit$point_ps_diagnostics),fit$bootstrap_ps_diagnostics)
    stopifnot(length(ps)==201L,all(vapply(ps,function(p)isTRUE(p$converged)&&p$normalized_score_max<=1e-7,logical(1))))
    summary<-data.frame(study=study,outcome=outcome,method="WDSM",M=M,estimate=estimate,
      SE=se,lower=ci[1],upper=ci[2],n=nrow(d),B=200L,CI_method="Wald; B-divisor fixed-original-reuse replication variance",variant=variant)
    fits<-list(WDSM=fit)
  } else {
    comparator_final_check_dependencies()
    fits<-list();rows<-list()
    for(method in c("DSM","PGM","PSM","SWPSM")) {
      if(study=="NSDUH")set.seed(2024)
      seed_start<-.Random.seed
      fit<-case_comparator(d,vars,method,study,repo)
      fit$seed_start<-seed_start;fit$seed_end<-.Random.seed
      fits[[method]]<-fit
      rows[[method]]<-data.frame(study=study,outcome=outcome,method=method,M=if(method=="SWPSM")NA_integer_ else 1L,
        estimate=fit$estimate,SE=fit$SE,lower=fit$lower,upper=fit$upper,n=nrow(d),
        B=if(method=="SWPSM")NA_integer_ else 200L,CI_method=fit$inference,variant=variant)
    }
    summary<-do.call(rbind,rows);rownames(summary)<-NULL
  }
  manifest$seed_end<-.Random.seed
  list(status="complete",summary=summary,fits=fits)
},error=function(e)list(status="failed",error=conditionMessage(e)))
result$manifest<-manifest;result$session<-sessionInfo()
result$finished_utc<-format(Sys.time(),tz="UTC",usetz=TRUE)
saveRDS(result,paste0(destination,".tmp"),version=3L)
stopifnot(file.rename(paste0(destination,".tmp"),destination))
if(result$status!="complete")stop(result$error)
write.csv(result$summary,sub("rds$","csv",destination),row.names=FALSE)
print(result$summary,digits=12)
