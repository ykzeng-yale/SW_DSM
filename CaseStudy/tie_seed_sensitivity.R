#!/usr/bin/env Rscript
# Predeclared 20 tie seeds per NSDUH outcome; identical data/nuisance/bootstrap
# streams. Diagnostic only: never choose the reported seed by its estimate/CI.
options(warn=2)
repo<-normalizePath(Sys.getenv("WDSM_REPO",getwd()))
out<-Sys.getenv("CASE_SENSITIVITY_OUTPUT")
task<-as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID",Sys.getenv("CASE_TASK_ID")))
stopifnot(task %in% 0:39,nzchar(out))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
path<-file.path(out,sprintf("sensitivity_%02d.rds",task))
if(file.exists(path))stop("Refusing to overwrite sensitivity record")
prepared<-Sys.getenv("WDSM_CASE_PREPARED_DIR")
if(!nzchar(prepared))stop("Set WDSM_CASE_PREPARED_DIR to the reconstructed analysis-data directory")
input<-file.path(normalizePath(prepared,mustWork=TRUE),"nsduh_rebuilt_17471.rds")
Sys.setenv(NSDUH_INPUT=input)
source(file.path(repo,"CaseStudy","NSDUH","prepare_nsduh.R"))
source(file.path(repo,"CaseStudy","NSDUH","wdsm_flexible.R"))
p<-nsduh_prepare_data(repo);d<-p$data
outcome<-c("AMIPY","SMIPY")[task%/%20+1L];seed<-620000L+task%%20+1L
d$Y<-d[[outcome]]
RNGkind("Mersenne-Twister","Inversion","Rejection");set.seed(2024)
start<-.Random.seed
result<-tryCatch({
  fit<-wdsm_flexible(d,"Y","A",p$ps_formula,p$pgs_formula,"ANALWT2_C",
    M=5L,B=200L,verbose=FALSE,tie_seed=seed,tie_rule="random")
  b<-fit$bootstrap_estimates;se<-sqrt(mean((b-mean(b))^2))
  stopifnot(length(b)==200L,all(is.finite(b)),abs(se-fit$se)<1e-12,
    fit$n_boot_valid==200L,fit$identity_error<1e-9)
  list(status="complete",summary=data.frame(outcome=outcome,tie_seed=seed,
    estimate=fit$estimate,SE=fit$se,lower=fit$ci_lower,upper=fit$ci_upper,
    CI_excludes_zero=fit$ci_lower>0|fit$ci_upper<0),draws=b,
    tie_diagnostics=fit$tie_diagnostics,point_ps=fit$point_ps_diagnostics,
    bootstrap_ps=fit$bootstrap_ps_diagnostics)
},error=function(e)list(status="failed",error=conditionMessage(e)))
result$seed_start<-start;result$seed_end<-.Random.seed
files<-c(file.path(repo,c("CaseStudy/tie_seed_sensitivity.R","CaseStudy/NSDUH/prepare_nsduh.R",
  "CaseStudy/NSDUH/wdsm_flexible.R","R/wdsm_ties.R")),input)
result$source_and_input_md5<-tools::md5sum(files)
result$session<-sessionInfo();result$job<-Sys.getenv("SLURM_JOB_ID")
saveRDS(result,path,version=3L)
if(result$status!="complete")stop(result$error)
print(result$summary,digits=12)
