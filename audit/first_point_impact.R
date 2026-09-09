local<-'/Users/yukang/Desktop/Yale Causal Inference Biostat Research (0318-)/PSM:DSM_SW/Code Experiment/0727 Test (SW_DSM)'
out<-'/Users/yukang/Documents/WDSM_PATE_bootstrap_20260909/audit'
pilot<-readRDS(file.path(out,'pilot_first_record.rds')); ee<-new.env();load(file.path(local,'SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData'),ee)
raw<-ee$SuperPopGen_GoodOverlap_AllinOne_0118_2025[[1]][pilot$sample_ids,]
dat<-data.frame(X1=raw$x1,X2=raw$x2,X3=raw$x3,X4=raw$x4,X5=raw$x5,X6=raw$x6,A=raw$z,Y=raw$y)
lp<-qlogis(.005)+log(.9)*dat$A+log(1.05)*dat$X1+log(1.1)*dat$X2+log(1.15)*dat$X3+log(1.1)*dat$X4+log(1.05)*dat$X5+log(1.1)*dat$X6
dat$survey_weight<-1/(exp(lp)/(1+exp(lp)))
rm(ee,raw);gc()
old<-new.env(parent=globalenv());stable<-new.env(parent=globalenv())
ex<-parse(file.path(local,'wdsm_ci_functions.R'))
for(x in ex)if(is.call(x)&&identical(x[[1]],as.name('<-'))) {eval(x,old);eval(x,stable)}
stable$glm<-function(formula,data,family,weights,...){
 X<-model.matrix(formula,data); yy<-model.response(model.frame(formula,data))
 glm.fit(X,yy,weights=weights,family=family,start=rep(0,ncol(X)),control=glm.control(epsilon=1e-12,maxit=100))
}
cat('Original point M5 start',format(Sys.time()),'\n');a<-old$wdsm_point_estimate(dat,M=5,use_bias_correction=TRUE,use_interaction_ps=TRUE,use_interaction_pg=TRUE)
cat('Stable point M5 start',format(Sys.time()),'\n');b<-stable$wdsm_point_estimate(dat,M=5,use_bias_correction=TRUE,use_interaction_ps=TRUE,use_interaction_pg=TRUE)
h<-new.env();load(file.path(local,'Doc/Results/Retrospective_GoodOverlap_CorCor_M135_1000rep.RData'),h)
paper<-h$all_results[[1]]$CorCor_M5$wdsm_multinomial$estimate
r<-list(sample=1,design='Retrospective_GoodOverlap_CorCor',M=5,old=a$tau,stable=b$tau,paper=paper,old_paper_difference=a$tau-paper,stable_old_difference=b$tau-a$tau,stable_old_relative_change=100*(b$tau-a$tau)/abs(a$tau),max_ps_difference=max(abs(a$e_score-b$e_score)),changed_matches_0=sum(!vapply(seq_along(a$matches_0),function(i)identical(a$matches_0[[i]],b$matches_0[[i]]),logical(1))),changed_matches_1=sum(!vapply(seq_along(a$matches_1),function(i)identical(a$matches_1[[i]],b$matches_1[[i]]),logical(1))))
print(r);saveRDS(r,file.path(out,'first_point_impact.rds'))
