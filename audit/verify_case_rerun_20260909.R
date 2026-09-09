# Validate sanitized Slurm artifacts, then export auditable participant-free tables.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop('Usage: Rscript verify_case_rerun_20260909.R RESULT_DIR REPO_ROOT')
result_dir <- normalizePath(args[1], mustWork = TRUE)
repo <- normalizePath(args[2], mustWork = TRUE)
expected <- c('NHANES_HbA1c_M1','NHANES_HbA1c_M3','NHANES_HbA1c_M5','NSDUH_AMIPY_M5','NSDUH_SMIPY_M5')
files <- file.path(result_dir,paste0(expected,'.rds'))
stopifnot(all(file.exists(files)))
records <- lapply(files,readRDS)
source_hash <- records[[1]]$manifest$source_md5
prior_csv <- file.path(repo,'CaseStudy','verification_20260909','previous_results_3356769.csv')
for (name in names(source_hash)) {
 path <- if (name == 'CaseStudy/Figures/results.csv') prior_csv else file.path(repo,name)
 stopifnot(identical(unname(tools::md5sum(path)),unname(source_hash[name])))
}
summaries <- draws <- diagnostics <- checks <- vector('list',5)
for (i in seq_along(records)) {
 z <- records[[i]]; b <- z$bootstrap_samples; B <- z$manifest$B
 stopifnot(identical(z$status,'complete'),B==200L,length(b)==B,all(is.finite(b)),
  z$manifest$commit=='8444359ef29b51790a6464fed7ffcb1b3aba7849',
  identical(z$manifest$source_md5,source_hash), z$manifest$task==i-1L,
  nrow(z$summary)==1L,z$summary$n_failed==0L)
 cfg <- z$manifest$config
 input_cfg <- if (z$manifest$study=='NHANES') cfg$nhanes_input else cfg$nsduh_input
 stopifnot(z$manifest$input_md5==input_cfg$md5,z$manifest$input_sha256==input_cfg$sha256,
  z$manifest$n==input_cfg$n)
 oracle_se <- sqrt(sum((b-sum(b)/B)^2)/B)
 oracle_ci <- z$summary$estimate + c(-1,1)*qnorm(.975)*oracle_se
 stopifnot(abs(oracle_se-z$summary$SE)<1e-12,
  max(abs(oracle_ci-c(z$summary$lower,z$summary$upper)))<1e-12)
 diag <- c(list(z$point_ps_diagnostics),z$bootstrap_ps_diagnostics)
 stopifnot(length(diag)==201L)
 diagnostics[[i]] <- do.call(rbind,lapply(seq_along(diag),function(j) {
  x <- diag[[j]]
  stopifnot(isTRUE(x$converged),is.finite(x$normalized_score_max),
   x$normalized_score_max<=1e-7,x$iterations>=1,x$iterations<=100,
   all(is.finite(x$probability_range)),min(x$probability_range)>.Machine$double.eps,
   max(x$probability_range)<1-.Machine$double.eps)
  data.frame(case=expected[i],replicate=j-1L,converged=x$converged,
   initialization=x$initialization,iterations=x$iterations,
   normalized_score_max=x$normalized_score_max,probability_min=min(x$probability_range),
   probability_max=max(x$probability_range),rank=x$rank,
   positive_weight_count=x$positive_weight_count)
 }))
 # The local R4.4.0 RNG protocol must reproduce the Slurm R4.4.2 start and end.
 do.call(RNGkind,as.list(cfg$RNGkind));set.seed(cfg$seed)
 if (z$manifest$study=='NHANES') {
  for (n in cfg$nhanes_input$prior_sample_sizes)
   for (draw in seq_len(cfg$nhanes_input$prior_draws_per_sample)) invisible(rmultinom(1,n,rep(1/n,n)))
  for (prior in seq_len(z$manifest$task))
   for (draw in seq_len(cfg$nhanes_input$original_draws_per_M)) invisible(rmultinom(1,z$manifest$n,rep(1/z$manifest$n,z$manifest$n)))
 }
 stopifnot(identical(.Random.seed,z$manifest$seed_start))
 for (draw in seq_len(B)) invisible(rmultinom(1,z$manifest$n,rep(1/z$manifest$n,z$manifest$n)))
 stopifnot(identical(.Random.seed,z$manifest$seed_end))
 summaries[[i]] <- z$summary
 draws[[i]] <- data.frame(case=expected[i],replicate=seq_len(B),estimate=b)
 checks[[i]] <- data.frame(case=expected[i],B=B,checked_PS_fits=length(diag),
  identity_error=z$identity_error,SE=oracle_se,
  point_change=z$delta_from_previous['estimate'],SE_change=z$delta_from_previous['SE'],
  lower_change=z$delta_from_previous['lower'],upper_change=z$delta_from_previous['upper'],
  max_PS_score=max(diagnostics[[i]]$normalized_score_max),
  source_hashes_match=TRUE,RNG_start_and_end_match=TRUE)
}
out <- file.path(repo,'CaseStudy','verification_20260909')
dir.create(out,recursive=TRUE,showWarnings=FALSE)
for (name in c('summaries','draws','diagnostics','checks'))
 write.csv(do.call(rbind,get(name)),file.path(out,paste0(name,'.csv')),row.names=FALSE)
cat('Verified five cases,1000 replication estimates,1005 numerical propensity checks,source hashes,and RNG states.\n')
