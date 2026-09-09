options(stringsAsFactors=FALSE)
local <- '/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Code Experiment/0727 Test (SW_DSM)'
out <- '/Users/yukang/Documents/WDSM_PATE_bootstrap_20260909/audit'
RNGkind('Mersenne-Twister','Inversion','Rejection')
rows <- list(); coeffs <- list()
for (ov in c('GoodOverlap','PoorOverlap')) {
 name <- paste0('SuperPopGen_',ov,'_AllinOne_0118_2025')
 f <- file.path(local,paste0(name,'.RData'))
 if(!file.exists(f))f<-file.path(local,'PATE Retrospective Pooroverlap M135 CorCor GLM',paste0(name,'.RData'))
 e<-new.env();load(f,e);raw<-e[[name]][[1L]]
 pop<-data.frame(X1=raw$x1,X2=raw$x2,X3=raw$x3,X4=raw$x4,X5=raw$x5,X6=raw$x6,A=raw$z,Y=raw$y,Cluster=raw$Cluster,Strata=raw$Strata,S=1L)
 rm(e,raw);gc()
 for (des in c('retrospective','prospective')) for(rep in 1:2) {
  set.seed(2025L+rep)
  if(des=='retrospective'){
   lp<-qlogis(5000/nrow(pop))+log(.9)*pop$A+log(1.05)*pop$X1+log(1.10)*pop$X2+log(1.15)*pop$X3+log(1.10)*pop$X4+log(1.05)*pop$X5+log(1.10)*pop$X6
   pr<-exp(lp)/(1+exp(lp));sel<-rbinom(nrow(pop),1,pr)==1L
   dat<-pop[sel,];dat$id<-which(sel);dat$w<-1/pr[sel]
  }else{
   pp<-pop;pp$ones<-1;pp$id<-seq_len(nrow(pp))
   size3<-c(rep(850/5,5),rep(750/5,5),rep(700/5,5),rep(650/5,5),rep(600/5,5),rep(400/5,5),rep(350/5,5),rep(300/5,5),rep(250/5,5),rep(150/5,5))
   dd<-sampling::mstage(pp,stage=list('stratified','cluster',''),varnames=list('Strata','Cluster','ones'),size=list(rep(100000,10),rep(5,10),size3),method=list('','srswor','srswor'))
   dat<-sampling::getdata(pp,dd)[[3L]];dat$w<-1/dat$Prob;rm(pp,dd)
  }
  if(des=='retrospective'&&ov=='GoodOverlap'&&rep==1){
   pilot<-readRDS(file.path(out,'pilot_first_record.rds'));cat('First sample IDs exact pilot match:',identical(dat$id,pilot$sample_ids),'\n')
  }
  for(interact in c(TRUE,FALSE)){
   form<-if(interact) A~X1+X2+X3+X4+X5+X6+X1:X2 else A~X1+X2+X3+X4+X5+X6
   X<-model.matrix(form,dat);w<-if(des=='retrospective')dat$w else rep(1,nrow(dat))
   fits<-list();warns<-list()
   for(typ in c('historical_default','normalized_default','raw_zero_start','normalized_zero_start')){
    ws<-if(startsWith(typ,'normalized')) w/mean(w) else w
    warning_messages<-character()
    fit<-withCallingHandlers({
     if(typ=='historical_default')glm.fit(X,dat$A,weights=ws,family=quasibinomial('logit'))
     else glm.fit(X,dat$A,weights=ws,family=quasibinomial('logit'),start=if(grepl('zero_start',typ)) rep(0,ncol(X)) else NULL,control=glm.control(epsilon=1e-12,maxit=100))
    },warning=function(w){warning_messages<<-c(warning_messages,conditionMessage(w));invokeRestart('muffleWarning')})
    fits[[typ]]<-fit;warns[[typ]]<-unique(warning_messages)
   }
   reference<-fits$normalized_zero_start
   for(typ in names(fits)){
    fit<-fits[[typ]];pr<-fit$fitted.values
    # Stable negative loglik from linear predictors, divided by total original weight.
    eta<-drop(X%*%fit$coefficients);ll<-sum(w*(dat$A*eta-(pmax(eta,0)+log1p(exp(-abs(eta))))))/sum(w)
    score<-max(abs(drop(crossprod(X,w*(dat$A-pr)))/sum(w)))
    rows[[length(rows)+1]]<-data.frame(overlap=ov,design=des,replicate=rep,PS=if(interact)'correct' else 'misspecified',solver=typ,n=nrow(dat),wmin=min(w),wmean=mean(w),wmax=max(w),converged=fit$converged,iter=fit$iter,minp=min(pr),maxp=max(pr),nearBoundary=sum(pr<1e-8|pr>1-1e-8),maxabsbeta=max(abs(fit$coefficients)),weightedLogLik=ll,maxScore=score,maxProbabilityDiff=max(abs(pr-reference$fitted.values)),maxCoefDiff=max(abs(fit$coefficients-reference$coefficients)),warnings=paste(warns[[typ]],collapse=';'))
    coeffs[[paste(ov,des,rep,interact,typ,sep='_')]]<-fit$coefficients
   }
  }
 }
}
z<-do.call(rbind,rows);write.csv(z,file.path(out,'point_ps_numerical_diagnostic.csv'),row.names=FALSE);saveRDS(coeffs,file.path(out,'point_ps_numerical_coefficients.rds'))
print(z[z$solver=='historical_default',c('overlap','design','replicate','PS','converged','iter','nearBoundary','maxabsbeta','weightedLogLik','maxScore','maxProbabilityDiff')],row.names=FALSE)
cat('Zero-start raw vs normalized max coef diffs=',max(z$maxCoefDiff[z$solver=='raw_zero_start']),'\n')
cat('Normalized default vs normalized zero max coef diffs=',max(z$maxCoefDiff[z$solver=='normalized_default']),'\n')
