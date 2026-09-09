# Synthetic metadata/format checks; no causal models or simulation reruns.
options(stringsAsFactors=FALSE)
source('StabilizedWDSM/Tables/read_stabilized_metrics.R')
fixture<-file.path(tempdir(),'stabilized_performance_fixture');dir.create(fixture)
g<-expand.grid(estimand=c('PATE','PATT'),design=c('Retrospective','Prospective'),overlap=c('GoodOverlap','PoorOverlap'),scenario=c('CorCor','MisCor','CorMis','MisMis'),M=c(1L,3L,5L),stringsAsFactors=FALSE)
g$cell<-with(g,paste(estimand,design,overlap,scenario,sep='_'));g$pilot<-TRUE;g$expected<-g$reference_success<-g$baseline_matched<-5L;g$stabilized_success<-5L;g$stabilized_failure<-0L
bad<-with(g,design=='Prospective' & overlap=='PoorOverlap' & scenario=='MisMis');g$stabilized_success[bad]<-4L;g$stabilized_failure[bad]<-1L;g$failure_rate<-g$stabilized_failure/5;g$primary_performance_available<-!bad;g$truth<-1;g$paired_success_n<-g$stabilized_success
g$reference_signed_relative_bias_percent<-ifelse(g$scenario=='MisMis',-2,1);g$reference_absolute_relative_bias_percent<-abs(g$reference_signed_relative_bias_percent);g$stabilized_signed_relative_bias_percent<-ifelse(g$scenario=='CorCor',-.5,.25);g$stabilized_absolute_relative_bias_percent<-abs(g$stabilized_signed_relative_bias_percent);g$reference_mc_sd<-.1;g$stabilized_mc_sd<-.09;g$reference_rmse<-.11;g$stabilized_rmse<-.1;g$absolute_relative_bias_reduction_mc_lower_pp<--.2;g$absolute_relative_bias_reduction_mc_upper_pp<-1.2
stab_cols<-c('stabilized_signed_relative_bias_percent','stabilized_absolute_relative_bias_percent','stabilized_mc_sd','stabilized_rmse','absolute_relative_bias_reduction_mc_lower_pp','absolute_relative_bias_reduction_mc_upper_pp');g[bad,stab_cols]<-NA_real_
# A large conditional value must never leak into any primary output.
g$conditional_stabilized_signed_relative_bias_percent<-999999
publish<-function(d){utils::write.csv(d,file.path(fixture,'stabilized_point_metrics.csv'),row.names=FALSE);h<-strsplit(system2('shasum',c('-a','256',shQuote(file.path(fixture,'stabilized_point_metrics.csv'))),stdout=TRUE),' +')[[1]][1];saveRDS(list(complete=TRUE,baseline_pairing_complete=TRUE,all_estimators_successful=FALSE,pilot=TRUE,expected_reps=5L,expected_cells=32L,expected_method_rows=96L,output_sha256=setNames(h,'stabilized_point_metrics.csv'),fixture='Fabricated values for software checks only'),file.path(fixture,'stabilized_point_summary_manifest.rds'))}
reject<-function(expr,pattern){e<-tryCatch({force(expr);NULL},error=identity);stopifnot(inherits(e,'error'),grepl(pattern,conditionMessage(e),ignore.case=TRUE))}
publish(g);reject(read_stabilized_metrics(fixture),'pilot');a<-read_stabilized_metrics(fixture,TRUE);stopifnot(nrow(a$metrics)==96,all(is.na(a$metrics$absolute_relative_bias_reduction_pp[bad])),all(a$metrics$absolute_relative_bias_reduction_pp[!bad]==g$reference_absolute_relative_bias_percent[!bad]-g$stabilized_absolute_relative_bias_percent[!bad]))
publish(g[-1,]);reject(read_stabilized_metrics(fixture,TRUE),'schema|counts')
x<-g;x$baseline_matched[1]<-4;publish(x);reject(read_stabilized_metrics(fixture,TRUE),'pairing|counts')
x<-g;x$stabilized_signed_relative_bias_percent[bad]<-999999;publish(x);reject(read_stabilized_metrics(fixture,TRUE),'primary')
publish(g);cat('\n',file=file.path(fixture,'stabilized_point_metrics.csv'),append=TRUE);reject(read_stabilized_metrics(fixture,TRUE),'checksum');publish(g)
out<-file.path(tempdir(),'stabilized_performance_rendered')
cmd<-vapply(c('--vanilla','StabilizedWDSM/Tables/generate_performance_outputs.R','--summary',fixture,'--output',out,'--pilot-preview'),shQuote,character(1));s<-system2(file.path(R.home('bin'),'Rscript'),cmd,stdout=TRUE,stderr=TRUE);if(!is.null(attr(s,'status')))stop(paste(s,collapse='\n'))
p<-read.csv(file.path(out,'primary_point_comparison.csv'));stopifnot(nrow(p)==96,!any(grepl('conditional',names(p))),all(is.na(p$stabilized_signed_relative_bias_percent[bad])))
md<-readLines(file.path(out,'point_comparison_tables.md'));stopifnot(!any(grepl('999999',md)),any(grepl('1/5',md)),any(grepl('PILOT DIAGNOSTIC',md)),any(grepl('Cor\\|Cor',md,fixed=TRUE)),length(list.files(out,pattern='\\.png$'))==3L,length(list.files(out,pattern='\\.pdf$'))==3L,length(list.files(out,pattern='_comparison.tex$'))==4L)
cat('PASS: pilot,checksum,grid,baseline-pairing,and partial-success-primary gates;96 rows;6 failed settings withheld;3 plots and4 complete comparison tables.\n')
cat('Synthetic render directory:',out,'\n')
qa<-file.path('StabilizedWDSM','audit','performance_rendering_fixture');dir.create(qa,recursive=TRUE,showWarnings=FALSE)
file.copy(list.files(out,full.names=TRUE),qa,overwrite=TRUE)

# A whole experiment with expected rho rejections remains renderable as a
# failure diagnostic; it must not manufacture any stabilized primary values.
x<-g;x$stabilized_success<-0L;x$stabilized_failure<-5L;x$failure_rate<-1
x$primary_performance_available<-FALSE;x$paired_success_n<-0L;x[stab_cols]<-NA_real_
publish(x);out_failed<-file.path(tempdir(),'stabilized_all_failed_rendered')
cmd<-vapply(c('--vanilla','StabilizedWDSM/Tables/generate_performance_outputs.R','--summary',fixture,'--output',out_failed,'--pilot-preview'),shQuote,character(1))
s<-system2(file.path(R.home('bin'),'Rscript'),cmd,stdout=TRUE,stderr=TRUE);if(!is.null(attr(s,'status')))stop(paste(s,collapse='\n'))
p<-read.csv(file.path(out_failed,'primary_point_comparison.csv'))
stopifnot(nrow(p)==96,all(is.na(p$stabilized_signed_relative_bias_percent)),all(is.na(p$absolute_relative_bias_reduction_pp)),all(p$stabilized_failure==5L))
cat('PASS: all 96 settings rejected; primary metrics remain absent and all three diagnostic plots render.\n')
