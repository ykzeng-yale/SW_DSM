# Synthetic five-replication fixture for rendering/routing checks only.
# These numbers are not simulation results and must never be used in the paper.
options(stringsAsFactors=FALSE)
fixture<-file.path(tempdir(),'wdsm_table_fixture');dir.create(fixture)
g<-expand.grid(method_key=c('WDSM_M1','WDSM_M3','WDSM_M5','DSM_M1','PGM_M1','PSM_M1','SWPSM_full'),scenario=c('CorCor','MisCor','CorMis','MisMis'),overlap=c('GoodOverlap','PoorOverlap'),design=c('Retrospective','Prospective'),estimand=c('PATE','PATT'),stringsAsFactors=FALSE)
g$cell<-with(g,paste(estimand,design,overlap,scenario,sep='_'));g$expected<-g$success<-g$n<-5L;g$B<-200L;g$alpha<-.05;g$pilot<-TRUE;g$truth<-1;g$signed_relative_bias_percent<-(seq_len(nrow(g))-112)/10;g$absolute_relative_bias_percent<-abs(g$signed_relative_bias_percent);g$relative_efficiency<-1.234;g$coverage<-.8
write.csv(g,file.path(fixture,'wdsm_final_metrics.csv'),row.names=FALSE)
hash<-strsplit(system2('shasum',c('-a','256',shQuote(file.path(fixture,'wdsm_final_metrics.csv'))),stdout=TRUE),' +')[[1]][1]
saveRDS(list(complete=TRUE,pilot=TRUE,expected_reps=5L,expected_cells=32L,expected_method_rows=224L,output_sha256=setNames(hash,'wdsm_final_metrics.csv'),fixture='TEST ONLY: fabricated metrics for table validation'),file.path(fixture,'wdsm_final_summary_manifest.rds'))
run<-function(args)system2(file.path(R.home('bin'),'Rscript'),vapply(c('--vanilla','Tables/generate_tables.R',args),shQuote,character(1)),stdout=TRUE,stderr=TRUE)
bad<-run(c('--summary',fixture,'--output',file.path(fixture,'no_pilot')));stopifnot(!is.null(attr(bad,'status')),grepl('Pilot summaries cannot',paste(bad,collapse='\n')))
out<-file.path(fixture,'rendered');ok<-run(c('--summary',fixture,'--output',out,'--pilot-preview'));stopifnot(is.null(attr(ok,'status')))
paths<-file.path(out,paste0(rep(c('Retrospective','Prospective'),each=2),'_',rep(c('GoodOverlap','PoorOverlap'),2),'.tex'))
stopifnot(all(file.exists(paths)))
for(p in paths){
 x<-readLines(p);methodrows<-x[grepl(' & ',x,fixed=TRUE)&!grepl('PS & PGS|multicolumn',x)]
 stopifnot(length(methodrows)==14L,all(vapply(strsplit(methodrows,' & ',fixed=TRUE),length,integer(1))==16L),sum(grepl('multirow{7}',methodrows,fixed=TRUE))==2L,any(grepl('PILOT DIAGNOSTIC; NOT MANUSCRIPT RESULTS',x,fixed=TRUE)))
 wr<-methodrows[grepl('WDSM ($M$=',methodrows,fixed=TRUE)]
 expected<-if(grepl('Prospective',p))' & \\texttimes & \\texttimes' else ' & \\checkmark & \\texttimes'
 stopifnot(length(wr)==6L,all(grepl(expected,wr,fixed=TRUE)),all(grepl('1.23',methodrows,fixed=TRUE)),all(grepl('80.0',methodrows,fixed=TRUE)))
}
again<-run(c('--summary',fixture,'--output',out,'--pilot-preview'));stopifnot(!is.null(attr(again,'status')),grepl('already exist',paste(again,collapse='\n')))
# Changed metrics are not accepted under the previous PASS checksum.
cat('\n',file=file.path(fixture,'wdsm_final_metrics.csv'),append=TRUE)
changed<-run(c('--summary',fixture,'--output',file.path(fixture,'changed'),'--pilot-preview'));stopifnot(!is.null(attr(changed,'status')),grepl('checksum',paste(changed,collapse='\n')))
preview<-file.path(out,'table_preview.tex')
writeLines(c('\\documentclass{article}','\\usepackage[margin=1in]{geometry}','\\usepackage{rotating,booktabs,multirow,array,amssymb}','\\usepackage[table]{xcolor}','\\begin{document}','\\input{All_4_Final_Simulation_Tables.tex}','\\end{document}'),preview)
cat('PASS: all4 tables have14 complete method rows/16 columns, correct design-specific weighting marks, signed bias/RE/coverage formatting, and explicit pilot labels; production-pilot, overwrite, and checksum failure gates work.\n')
cat('Synthetic preview:',preview,'\n')
# Keep a small, conspicuously named rendering artifact for inspection.
qa<-file.path('audit','table_rendering_fixture');dir.create(qa,showWarnings=FALSE)
file.copy(c(file.path(out,'All_4_Final_Simulation_Tables.tex'),preview),qa,overwrite=TRUE)
