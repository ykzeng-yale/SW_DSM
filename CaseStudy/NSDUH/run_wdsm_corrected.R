# Run from the repository root. Supply the original input locally; no automatic downloads.
repo <- normalizePath(getwd(), mustWork=TRUE)
options(warn=2)
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
rows <- list()
source(file.path(repo,"CaseStudy","NSDUH","prepare_nsduh.R"))
ns <- new.env()
sys.source(file.path(repo,"CaseStudy","NSDUH","wdsm_flexible.R"),ns)
prep <- nsduh_prepare_data(repo)
for(outcome in c("AMIPY","SMIPY")) {
  nd <- prep$data
  nd$Y <- nd[[outcome]]
  set.seed(2024)
  fit <- ns$wdsm_flexible(nd,"Y","A",prep$ps_formula,prep$pgs_formula,
    "ANALWT2_C",M=5,B=200,verbose=TRUE)
  rows[[outcome]] <- data.frame(study="NSDUH",outcome=outcome,M=5,
    estimate=fit$estimate,SE=fit$se,lower=fit$ci_lower,upper=fit$ci_upper)
}
tab <- do.call(rbind,rows)
rownames(tab) <- NULL
reference <- read.csv(file.path(repo,"CaseStudy","Figures","results.csv"))
reference <- subset(reference,method=="WDSM")
key <- function(x) paste(x$study,x$outcome,x$M)
reference <- reference[match(key(tab),key(reference)),]
stopifnot(max(abs(as.matrix(tab[,c("estimate","SE","lower","upper")])-
  as.matrix(reference[,c("estimate","SE","lower","upper")]))) < 1e-8)
write.csv(tab,file.path(repo,"CaseStudy","NSDUH","rerun_wdsm_summary.csv"),row.names=FALSE)
print(tab,digits=12)
cat("Verified against the published numerical table. This is not a proof of inference validity.\n")
