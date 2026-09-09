options(stringsAsFactors=FALSE)
source('R/comparators_final.R')
comparator_final_check_dependencies()
plain <- new.env(parent=asNamespace('stats'))
for(f in c('is.lp.R','is.ps.R','is.pg.R','dsmatchATE.R','dsmatchATT.R','estforboot_dsATE.R','estforboot_psATE.R','estforboot_pgATE.R','estforboot_dsATT.R','estforboot_psATT.R','estforboot_pgATT.R'))sys.source(file.path('R/dsmatch',f),plain)
set.seed(791);n<-250L;d<-as.data.frame(matrix(rnorm(n*6),n,6));names(d)<-paste0('X',1:6);d$A<-rbinom(n,1,plogis(.4*d$X1-.2*d$X2));d$Y<-d$A+.3*d$X1+.1*d$X1*d$X2+rnorm(n);d$survey_weight<-exp(.2*d$X1)
rows<-list()
for(e in c('PATE','PATT'))for(ps in c(TRUE,FALSE))for(pg in c(TRUE,FALSE))for(m in c('DSM','PGM','PSM')){
 X<-as.matrix(d[paste0('X',1:6)]);xp<-if(ps)cbind(X,X1X2=X[,1]*X[,2]) else X;xg<-if(pg)cbind(X,X1X2=X[,1]*X[,2]) else X
 args<-list(Y=d$Y,A=d$A,X=if(m=='PGM')xg else xp,method=switch(m,DSM='dsm',PGM='pg',PSM='ps'),cov.balance=FALSE,varest=TRUE,boots=5L,mc=FALSE,ncpus=1L)
 if(m %in% c('DSM','PSM'))args$model.ps<-'logit'
 if(m=='PGM')args$model.pg<-'glm'
 if(m=='DSM'){args$model.pg<-'linpred';args$lp.pg<-xg}
 set.seed(815);original<-do.call(plain[[if(e=='PATE')'dsmatchATE' else 'dsmatchATT']],args)
 set.seed(815);checked<-compare_final(d,method=m,estimand=e,B=5,use_interaction_ps=ps,use_interaction_pg=pg,repo='.')
 a<-as.numeric(original[[switch(m,DSM='est.ds',PGM='est.pg',PSM='est.ps')]]);v<-as.numeric(original$bootvar)
 stopifnot(identical(a,checked$estimate),identical(v,checked$variance),length(checked$diagnostics$bootstrap_draws)==5L,checked$diagnostics$bootstrap_successful==5L,checked$diagnostics$variance_divisor==4L,abs(var(checked$diagnostics$bootstrap_draws)-checked$variance)<1e-14)
 rows[[length(rows)+1L]]<-data.frame(estimand=e,PS=ps,PG=pg,method=m,estimate_diff=checked$estimate-a,variance_diff=checked$variance-v,bootstrap_successful=checked$diagnostics$bootstrap_successful,warnings=paste(checked$diagnostics$warnings,collapse=';'))
}
for(e in c('PATE','PATT'))for(ps in c(TRUE,FALSE)){
 df<-d;df$sw<-df$survey_weight*nrow(df)/sum(df$survey_weight)
 f<-if(ps)A~X1+X2+X3+X4+X5+X6+X1:X2 else A~X1+X2+X3+X4+X5+X6
 set.seed(815);ma<-MatchIt::matchit(f,data=df,method='full',distance='glm',link='logit',estimand=if(e=='PATE')'ATE' else 'ATT',s.weights=df$sw,verbose=FALSE)
 md<-MatchIt::match.data(ma);fit<-lm(Y~A*(X1+X2+X3+X4+X5+X6+X1:X2),data=md,weights=weights)
 avg<-marginaleffects::avg_comparisons(fit,newdata=if(e=='PATE')md else subset(md,A==1),variables='A',vcov=~subclass,wts='sw')
 set.seed(815);checked<-compare_final(d,method='SWPSM',estimand=e,B=5,use_interaction_ps=ps,repo='.')
 stopifnot(abs(checked$estimate-avg$estimate)<1e-12,abs(checked$se-avg$std.error)<1e-10,checked$diagnostics$bootstrap_requested==0L)
 rows[[length(rows)+1L]]<-data.frame(estimand=e,PS=ps,PG=NA,method='SWPSM',estimate_diff=checked$estimate-avg$estimate,variance_diff=checked$variance-avg$std.error^2,bootstrap_successful=0L,warnings=paste(checked$diagnostics$warnings,collapse=';'))
}
# The private variance hook must refuse any silently dropped replicate.
l<-new.env(parent=emptyenv());l$glm_fits<-l$lm_fits<-l$rank_deficient_lm<-0L;l$bootstrap_draws<-numeric();en<-.comparator_final_vendor('.',5L,l)
error_expected<-function(expr,pattern){er<-tryCatch({force(expr);NULL},error=identity);stopifnot(inherits(er,'error'),grepl(pattern,conditionMessage(er)))}
error_expected(en$var(matrix(c(1:4,NA),ncol=1),na.rm=TRUE),'nonfinite')
error_expected(en$var(matrix(1:4,ncol=1),na.rm=TRUE),'Unexpected')
error_expected(compare_final(d,method='DSM',M=3),'M=1')
error_expected(compare_final(transform(d,A=0),method='PSM'),'both arms')
error_expected(compare_final(d,survey_weight=rep(0,n),method='SWPSM'),'positive finite')
z<-do.call(rbind,rows);write.csv(z,'audit/comparator_final_validation.csv',row.names=FALSE);print(z);cat('PASS: 24 exact vendor estimate/variance comparisons, 4 historical SWPSM comparisons, 5 invalid-input/draw checks.\n')
