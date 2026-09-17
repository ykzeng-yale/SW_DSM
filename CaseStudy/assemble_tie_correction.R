#!/usr/bin/env Rscript
# Independent assembly: all 16 tasks / 25 rows required, never a successful subset.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=2L)stop("Usage: Rscript CaseStudy/assemble_tie_correction.R INPUT_DIR NEW_OUTPUT_DIR")
repo<-normalizePath(getwd());input<-normalizePath(args[1]);out<-args[2]
if(dir.exists(out)&&length(list.files(out,all.files=TRUE,no..=TRUE)))stop("Choose a new output directory")
paths<-file.path(input,sprintf("task_%02d.rds",0:15))
stopifnot(all(file.exists(paths)))
records<-lapply(paths,readRDS)
stopifnot(all(vapply(records,function(x)identical(x$status,"complete"),logical(1))))
commit<-records[[1]]$manifest$commit
hashes<-records[[1]]$manifest$source_md5
for(p in names(hashes)) {
  tmp<-tempfile()
  status<-system2("git",c("show",shQuote(paste0(commit,":",p))),stdout=tmp)
  stopifnot(status==0L,unname(tools::md5sum(tmp))==unname(hashes[p]));unlink(tmp)
}
tie_rows<-draw_rows<-check_rows<-list()
for(i in seq_along(records)) {
  r<-records[[i]];m<-r$manifest;s<-r$summary
  stopifnot(m$task==i-1L,identical(m$commit,commit),identical(m$source_md5,hashes),
    all(is.finite(as.matrix(s[c("estimate","SE","lower","upper")]))))
  input_file<-if(m$study=="NSDUH")"CaseStudy/data_preparation_20260917/nsduh_rebuilt_17471.rds" else
    if(m$variant=="legacy_row_order")"CaseStudy/NHANES/data/WDSM_M1_M3_M5_ANALYSIS_10.rda" else
      "CaseStudy/data_preparation_20260917/nhanes_clean_3790.rds"
  stopifnot(unname(tools::md5sum(input_file))==m$input_md5)
  if(i<=13L) {
    f<-r$fits$WDSM;b<-f$bootstrap_estimates
    stopifnot(nrow(s)==1L,length(b)==200L,all(is.finite(b)))
    se<-sqrt(sum((b-sum(b)/200)^2)/200)
    stopifnot(abs(se-s$SE)<1e-12,max(abs(s$estimate+c(-1,1)*qnorm(.975)*se-c(s$lower,s$upper)))<1e-12)
    td<-f$tie_diagnostics
    stopifnot(td$rule==m$tie_rule,td$seed==m$tie_seed,
      td$original_match_sets_fixed_in_replication)
    matches<-if(m$study=="NHANES")f$point_estimate else f
    d<-if(m$study=="NSDUH")readRDS(input_file) else if(m$variant=="legacy_row_order") {
      e<-new.env();load(input_file,e);e$data_prep
    } else readRDS(input_file)
    A<-if(m$study=="NSDUH")d$early_mj_use else as.numeric(d$sld012<7)
    for(arm in 0:1) {
      sets<-matches[[paste0("matches_",arm)]];receivers<-which(A!=arm)
      stopifnot(length(sets)==length(A),all(vapply(sets[receivers],length,integer(1))==m$M),
        all(vapply(sets[receivers],function(j)!anyDuplicated(j)&&all(A[j]==arm),logical(1))))
      a<-td$arms[[as.character(arm)]]
      counts<-tabulate(unlist(sets[receivers]),nbins=length(A))
      stopifnot(sum(counts)==a$total_selected_pairs,max(counts)==a$maximum_donor_reuse_count,
        sum(counts>0)==a$donors_used)
      tie_rows[[length(tie_rows)+1L]]<-data.frame(task=m$task,study=m$study,outcome=m$outcome,
        M=m$M,variant=m$variant,donor_arm=arm,recipients=length(receivers),
        exact_tie_recipients=a$exact_boundary_tie_recipients,
        boundary_tie_recipients=a$boundary_tie_recipients,randomized_recipients=a$randomized_recipients,
        donors_used=a$donors_used,max_donor_reuse=a$maximum_donor_reuse_count,
        maximum_boundary_group=a$maximum_boundary_group)
    }
    ps<-c(list(f$point_ps_diagnostics),f$bootstrap_ps_diagnostics)
    stopifnot(length(ps)==201L,all(vapply(ps,function(x)isTRUE(x$converged)&&
      x$normalized_score_max<=1e-7&&min(x$probability_range)>.Machine$double.eps&&
      max(x$probability_range)<1-.Machine$double.eps,logical(1))))
    RNGkind("Mersenne-Twister","Inversion","Rejection");assign(".Random.seed",m$seed_start,.GlobalEnv)
    for(bi in seq_len(200L))invisible(rmultinom(1,m$n,rep(1/m$n,m$n)))
    stopifnot(identical(.Random.seed,m$seed_end))
    draw_rows[[length(draw_rows)+1L]]<-data.frame(task=m$task,study=m$study,outcome=m$outcome,
      method="WDSM",M=m$M,variant=m$variant,replicate=1:200,estimate=b)
    check_rows[[length(check_rows)+1L]]<-data.frame(task=m$task,draws=200L,PS_fits=201L,
      max_score=max(vapply(ps,function(x)x$normalized_score_max,numeric(1))),source_hashes=TRUE,
      input_hash=TRUE,Wald=TRUE,RNG_end=TRUE,match_sets=TRUE)
  } else for(method in names(r$fits)) {
    f<-r$fits[[method]];row<-s[s$method==method,]
    if(method!="SWPSM") {
      stopifnot(length(f$draws)==200L,all(is.finite(f$draws)),f$divisor==199L,
        abs(sd(f$draws)-row$SE)<1e-12,
        max(abs(row$estimate+c(-1,1)*1.96*row$SE-c(row$lower,row$upper)))<1e-12)
      draw_rows[[length(draw_rows)+1L]]<-data.frame(task=m$task,study=m$study,outcome=m$outcome,
        method=method,M=1L,variant=m$variant,replicate=1:200,estimate=f$draws)
    } else stopifnot(max(abs(row$estimate+c(-1,1)*qnorm(.975)*row$SE-c(row$lower,row$upper)))<1e-10)
  }
}
all_rows<-do.call(rbind,lapply(records,`[[`,"summary"));rownames(all_rows)<-NULL
stopifnot(nrow(all_rows)==25L)
final<-all_rows[all_rows$variant=="corrected",setdiff(names(all_rows),"variant")]
stopifnot(nrow(final)==17L,all(final$n[final$study=="NHANES"]==3790L),all(final$n[final$study=="NSDUH"]==17471L))
baseline<-read.csv("CaseStudy/Results/Final_20260917/results.csv")
key<-function(x)paste(x$study,x$outcome,x$method,x$M)
final<-final[match(key(baseline),key(final)),];stopifnot(!anyNA(final$estimate))
comparison<-baseline[,c("study","outcome","method","M")]
for(v in c("estimate","SE","lower","upper","n")) {
  comparison[[paste0("previous_",v)]]<-baseline[[v]]
  comparison[[paste0("updated_",v)]]<-final[[v]]
  comparison[[paste0("delta_",v)]]<-final[[v]]-baseline[[v]]
}
comparison$previous_CI_excludes_zero<-baseline$lower>0|baseline$upper<0
comparison$updated_CI_excludes_zero<-final$lower>0|final$upper<0
comparison$CI_exclusion_changed<-comparison$previous_CI_excludes_zero!=comparison$updated_CI_excludes_zero
decomposition<-list()
for(i in 1:5) {
  new<-records[[i]]$summary;old<-records[[i+5]]$summary
  clean<-if(i<=3)records[[i+10]]$summary else old
  row<-new[,c("study","outcome","method","M")]
  for(v in c("estimate","SE","lower","upper")) {
    row[[paste0("legacy_",v)]]<-old[[v]]
    row[[paste0("missing_code_change_",v)]]<-clean[[v]]-old[[v]]
    row[[paste0("tie_rule_change_",v)]]<-new[[v]]-clean[[v]]
    row[[paste0("updated_",v)]]<-new[[v]]
  }
  decomposition[[i]]<-row
}
dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(final,file.path(out,"results.csv"),row.names=FALSE)
write.csv(all_rows,file.path(out,"all_25_rerun_rows.csv"),row.names=FALSE)
write.csv(comparison,file.path(out,"comparison_with_previous.csv"),row.names=FALSE)
write.csv(do.call(rbind,decomposition),file.path(out,"change_decomposition.csv"),row.names=FALSE)
write.csv(do.call(rbind,tie_rows),file.path(out,"tie_allocation_diagnostics.csv"),row.names=FALSE)
write.csv(do.call(rbind,draw_rows),file.path(out,"all_bootstrap_draws.csv"),row.names=FALSE)
write.csv(do.call(rbind,check_rows),file.path(out,"independent_checks.csv"),row.names=FALSE)
source("CaseStudy/verify_results.R")
write_case_tables(final,out,"All 17 rows rerun from reconstructed full-source data; recipient-specific randomized WDSM ties; NHANES n=3790. Discrete-score inference validity is not established by numerical checks alone.")
saveRDS(list(commit=commit,source_md5=hashes,inputs_md5=tools::md5sum(paths),
  tasks=16L,rows=25L,primary_rows=17L,WDSM_draws_checked=2600L,
  comparator_draws_checked=1800L,PS_fits_checked=2613L,all_checks_passed=TRUE,
  assembled_utc=format(Sys.time(),tz="UTC",usetz=TRUE),session=sessionInfo()),
  file.path(out,"verification_manifest.rds"),version=3L)
print(final,digits=10)
print(comparison[comparison$CI_exclusion_changed,])
