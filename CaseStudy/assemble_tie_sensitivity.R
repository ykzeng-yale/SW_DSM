#!/usr/bin/env Rscript
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=2L)stop("Usage: assemble_tie_sensitivity.R INPUT_DIR NEW_OUTPUT_DIR")
paths<-file.path(args[1],sprintf("sensitivity_%02d.rds",0:39))
stopifnot(all(file.exists(paths)))
out<-args[2]
if(dir.exists(out)&&length(list.files(out,all.files=TRUE,no..=TRUE)))stop("Choose a new output directory")
records<-lapply(paths,readRDS);checks<-draws<-list()
for(i in seq_along(records)) {
  x<-records[[i]];s<-x$summary;b<-x$draws
  stopifnot(x$status=="complete",s$outcome==c("AMIPY","SMIPY")[(i-1L)%/%20L+1L],
    s$tie_seed==620001L+(i-1L)%%20L,identical(x$source_and_input_md5,records[[1]]$source_and_input_md5),
    length(b)==200L,all(is.finite(b)),abs(s$SE-sqrt(mean((b-mean(b))^2)))<1e-12,
    max(abs(s$estimate+c(-1,1)*qnorm(.975)*s$SE-c(s$lower,s$upper)))<1e-12)
  ps<-c(list(x$point_ps),x$bootstrap_ps)
  stopifnot(length(ps)==201L,all(vapply(ps,function(p)isTRUE(p$converged)&&
    p$normalized_score_max<=1e-7&&min(p$probability_range)>.Machine$double.eps&&
    max(p$probability_range)<1-.Machine$double.eps,logical(1))))
  RNGkind("Mersenne-Twister","Inversion","Rejection");set.seed(2024)
  stopifnot(identical(.Random.seed,x$seed_start))
  for(j in 1:200)invisible(rmultinom(1,17471,rep(1/17471,17471)))
  stopifnot(identical(.Random.seed,x$seed_end),x$tie_diagnostics$seed==s$tie_seed)
  checks[[i]]<-data.frame(outcome=s$outcome,tie_seed=s$tie_seed,draws=200,PS_fits=201,
    max_PS_score=max(vapply(ps,function(p)p$normalized_score_max,numeric(1))),
    RNG_verified=TRUE,Wald_verified=TRUE)
  draws[[i]]<-data.frame(outcome=s$outcome,tie_seed=s$tie_seed,replicate=1:200,estimate=b)
}
table<-do.call(rbind,lapply(records,`[[`,"summary"));rownames(table)<-NULL
summary<-do.call(rbind,lapply(split(table,table$outcome),function(d)data.frame(outcome=d$outcome[1],
  seeds=nrow(d),min_estimate=min(d$estimate),max_estimate=max(d$estimate),
  mean_estimate=mean(d$estimate),SD_across_tie_seeds=sd(d$estimate),
  min_SE=min(d$SE),max_SE=max(d$SE),min_lower=min(d$lower),max_lower=max(d$lower),
  min_upper=min(d$upper),max_upper=max(d$upper),
  CIs_excluding_zero=sum(d$CI_excludes_zero),CIs_including_zero=sum(!d$CI_excludes_zero))))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(table,file.path(out,"all_40_fits.csv"),row.names=FALSE)
write.csv(summary,file.path(out,"sensitivity_summary.csv"),row.names=FALSE)
write.csv(do.call(rbind,checks),file.path(out,"verification_checks.csv"),row.names=FALSE)
write.csv(do.call(rbind,draws),file.path(out,"all_8000_draws.csv"),row.names=FALSE)
saveRDS(list(records=40L,draws_checked=8000L,PS_fits_checked=8040L,
  source_and_input_md5=records[[1]]$source_and_input_md5,all_checks_passed=TRUE,
  interpretation="Algorithmic seed sensitivity, not a confidence interval or Monte Carlo bias estimate. Primary seed 20260922 is unchanged.",
  input_files_md5=tools::md5sum(paths)),file.path(out,"verification_manifest.rds"),version=3L)
print(summary,digits=12)
