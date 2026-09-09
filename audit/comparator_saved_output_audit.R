rows<-list()
for(est in c('PATE','PATT'))for(f in sort(list.files(file.path('Results',est),pattern='1000rep.RData$',full.names=TRUE))){
 e<-new.env();load(f,e);sc<-sub('.*_(CorCor|CorMis|MisCor|MisMis)_M135.*','\\1',f)
 for(M in c(1L,3L,5L))for(method in c('dsm_unweighted','pg_unweighted','ps_unweighted','ps_weighted')){
  vals<-t(vapply(e$all_results,function(r){ z<-r[[paste0(sc,'_M',M)]][[method]];vapply(c('estimate','se','ci_lower','ci_upper'),function(k){v<-unlist(z[[k]]);if(length(v)==1)as.numeric(v) else NA_real_},numeric(1))},numeric(4)))
  paired<-apply(vals,1,function(r)all(is.finite(r)));ok<-vals[paired,,drop=FALSE]
  err<-if(nrow(ok))max(abs(ok[,3:4]-cbind(ok[,1]-qnorm(.975)*ok[,2],ok[,1]+qnorm(.975)*ok[,2]))) else NA_real_
  rows[[length(rows)+1L]]<-data.frame(estimand=est,file=basename(f),scenario=sc,M=M,method=method,records=nrow(vals),finite_records=sum(paired),missing_est=sum(!is.finite(vals[,1])),missing_se=sum(!is.finite(vals[,2])),missing_lower=sum(!is.finite(vals[,3])),missing_upper=sum(!is.finite(vals[,4])),nonpositive_se=sum(ok[,2]<=0),inverted_ci=sum(ok[,3]>ok[,4]),max_wald_endpoint_error=err,truth=e$true_pate,coverage=mean(ok[,3]<=e$true_pate & ok[,4]>=e$true_pate))
 }
}
z<-do.call(rbind,rows);write.csv(z,'audit/comparator_saved_output_audit.csv',row.names=FALSE)
print(aggregate(cbind(records,finite_records,missing_est,missing_se,missing_lower,missing_upper,nonpositive_se,inverted_ci)~estimand+method,z,sum));print(aggregate(max_wald_endpoint_error~method,z,max));print(z[z$finite_records<1000,])
