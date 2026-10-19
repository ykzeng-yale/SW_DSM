#!/usr/bin/env Rscript
# Primary NSDUH analysis. Task IDs preserve the recorded publication mapping.
# Tasks 3/4: WDSM AMIPY/SMIPY. Tasks 14/15: their four comparators.
options(warn=2)
args <- commandArgs(trailingOnly=TRUE)
if(!length(args) %in% 1:2)
  stop("Usage: Rscript CaseStudy/analyze_nsduh.R NEW_OUTPUT_DIRECTORY [TASK_ID]")
repo <- normalizePath(Sys.getenv("WDSM_REPO",getwd()),mustWork=TRUE)
output <- path.expand(args[1L])
tasks <- if(length(args)==2L) as.integer(args[2L]) else c(3L,4L,14L,15L)
stopifnot(length(tasks)>0L,!anyNA(tasks),all(tasks %in% c(3L,4L,14L,15L)))
dir.create(output,recursive=TRUE,showWarnings=FALSE)
output <- normalizePath(output,mustWork=TRUE)
if(identical(output,repo)||startsWith(output,paste0(repo,.Platform$file.sep)))
  stop("Use an output directory outside the repository; saved fits contain participant data")
destinations <- file.path(output,sprintf("task_%02d.rds",tasks))
if(any(file.exists(destinations)))stop("Refusing to overwrite existing NSDUH task records")
if(length(tasks)==4L&&file.exists(file.path(output,"results.csv")))
  stop("Refusing to overwrite existing NSDUH results.csv")
for(task in tasks) {
destination <- file.path(output,sprintf("task_%02d.rds",task))
RNGkind("Mersenne-Twister","Inversion","Rejection")
source(file.path(repo,"CaseStudy","NSDUH","prepare_nsduh.R"))
source(file.path(repo,"R","comparators_final.R"))
source(file.path(repo,"CaseStudy","comparators_from_raw.R"))
study <- "NSDUH"
outcome <- if(task %in% c(3L,14L)) "AMIPY" else "SMIPY"
M <- 5L
prepared <- Sys.getenv("WDSM_CASE_PREPARED_DIR")
if(!nzchar(prepared))stop("Set WDSM_CASE_PREPARED_DIR to the reconstructed analysis-data directory")
input<-file.path(normalizePath(prepared,mustWork=TRUE),"nsduh_rebuilt_17471.rds")
Sys.setenv(NSDUH_INPUT=input)
prep<-nsduh_prepare_data(repo);d<-prep$data;vars<-prep$covariates
d$Y<-d[[outcome]];d$survey_weight<-d$ANALWT2_C
stopifnot(nrow(d)==17471L,sum(d$A)==1877L,length(unique(do.call(paste,d[vars])))==1276L,
  all(complete.cases(d[,c("Y","A","survey_weight",vars)])))
source_files<-c("CaseStudy/analyze_nsduh.R","CaseStudy/comparators_from_raw.R",
  "CaseStudy/prepare_from_raw.R","CaseStudy/NSDUH/prepare_nsduh.R",
  "CaseStudy/NSDUH/wdsm_flexible.R","R/wdsm_ties.R","R/comparators_final.R",
  paste0("R/dsmatch/",list.files(file.path(repo,"R","dsmatch"),pattern="\\.R$")))
manifest<-list(task=task,study=study,outcome=outcome,M=M,
  B=200L,n=nrow(d),n_treated=sum(d$A),input_md5=unname(tools::md5sum(input)),
  source_md5=setNames(tools::md5sum(file.path(repo,source_files)),source_files),
  tie_seed=20260917L+M,tie_rule="random",
  bootstrap_seed_protocol="Reset to 2024 for each method and outcome",
  job_id=Sys.getenv("SLURM_JOB_ID"),started_utc=format(Sys.time(),tz="UTC",usetz=TRUE))
result <- tryCatch({
  set.seed(2024)
  if(task %in% c(3L,4L)) {
    manifest$seed_start<-.Random.seed
    case<-new.env()
    sys.source(file.path(repo,"CaseStudy","NSDUH","wdsm_flexible.R"),case)
    fit<-case$wdsm_flexible(d,"Y","A",prep$ps_formula,prep$pgs_formula,"ANALWT2_C",
      M=M,B=200L,verbose=FALSE,tie_seed=manifest$tie_seed,tie_rule=manifest$tie_rule)
    estimate<-fit$estimate;identity_error<-fit$identity_error
    draws<-fit$bootstrap_estimates
    se<-sqrt(mean((draws-mean(draws))^2));ci<-estimate+c(-1,1)*qnorm(.975)*se
    stopifnot(length(draws)==200L,all(is.finite(draws)),identity_error<1e-9,
      abs(fit$se-se)<1e-12,max(abs(c(fit$ci_lower,fit$ci_upper)-ci))<1e-12)
    ps<-c(list(fit$point_ps_diagnostics),fit$bootstrap_ps_diagnostics)
    stopifnot(length(ps)==201L,all(vapply(ps,function(p)isTRUE(p$converged)&&p$normalized_score_max<=1e-7,logical(1))))
    summary<-data.frame(study=study,outcome=outcome,method="WDSM",M=M,estimate=estimate,
      SE=se,lower=ci[1],upper=ci[2],n=nrow(d),B=200L,CI_method="Wald; B-divisor fixed-original-reuse replication variance")
    fits<-list(WDSM=fit)
  } else {
    comparator_final_check_dependencies()
    fits<-list();rows<-list()
    for(method in c("DSM","PGM","PSM","SWPSM")) {
      set.seed(2024)
      seed_start<-.Random.seed
      fit<-case_comparator(d,vars,method,study,repo)
      fit$seed_start<-seed_start;fit$seed_end<-.Random.seed
      fits[[method]]<-fit
      rows[[method]]<-data.frame(study=study,outcome=outcome,method=method,M=if(method=="SWPSM")NA_integer_ else 1L,
        estimate=fit$estimate,SE=fit$SE,lower=fit$lower,upper=fit$upper,n=nrow(d),
        B=if(method=="SWPSM")NA_integer_ else 200L,CI_method=fit$inference)
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
}
if(length(tasks)==4L) {
  records <- lapply(destinations,readRDS)
  final <- do.call(rbind,lapply(records,`[[`,"summary"))
  final <- final[order(match(final$outcome,c("AMIPY","SMIPY")),
    match(final$method,c("PSM","PGM","DSM","SWPSM","WDSM"))),]
  rownames(final) <- NULL
  stopifnot(nrow(final)==10L)
  write.csv(final,file.path(output,"results.csv"),row.names=FALSE)
}
