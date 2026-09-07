# Run from the repository root. Requires original saved case-study inputs.
# Writes aggregate results only. No automatic downloads or package installation.
repo <- normalizePath(getwd(), mustWork=TRUE)
here <- file.path(repo, "CaseStudy", "verified_2026_09")
cases <- file.path(repo, "CaseStudy", "0727 Test (SW_DSM)", "Case Study Data")
stopifnot(file.exists(file.path(here, "prepare_nsduh.R")))
options(warn=2)
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
rows <- list()
nh <- new.env()
sys.source(file.path(cases, "NHANES", "WDSM_adaptive.R"), nh)
saved <- new.env()
load(file.path(cases, "NHANES", "WDSM_M1_M3_M5_ANALYSIS_10.rda"), saved)
raw <- saved$data_prep
vars <- c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi","smq020")
d <- as.data.frame(raw)
d$Y <- d$lbxgh
d$A <- as.numeric(d$sld012 < 7)
d$survey_weight <- d$wtmec2yr
stopifnot(nrow(d)==3793, all(complete.cases(d[,c("Y","A","survey_weight",vars)])))
# Original all-analysis runner seeds once. Advance only its multinomial calls.
set.seed(2024)
for (previous_n in c(12164,5876,14021,14381,8973)) {
  for (b in seq_len(150)) invisible(rmultinom(1,previous_n,rep(1/previous_n,previous_n)))
}
starts <- list()
for (M in c(1,3,5)) {
  starts[[as.character(M)]] <- .Random.seed
  for (b in seq_len(50)) invisible(rmultinom(1,nrow(d),rep(1/nrow(d),nrow(d))))
}
for (M in c(1,3,5)) {
  .Random.seed <- starts[[as.character(M)]]
  fit <- nh$bootstrap_adaptive_wdsm(d,reformulate(vars,"A"),reformulate(vars),
    M=M,n_bootstrap=200,seed=NULL,sampling_design="retrospective")
  rows[[paste0("NHANES",M)]] <- data.frame(study="NHANES",outcome="HbA1c",M=M,
    estimate=fit$point_estimate$tau,SE=fit$se,lower=fit$ci_lower,upper=fit$ci_upper)
}
source(file.path(here,"prepare_nsduh.R"))
ns <- new.env()
sys.source(file.path(cases,"SAMHSA 0914","Analysis","Scripts","wdsm_flexible.R"),ns)
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
reference <- read.csv(file.path(here,"results.csv"))
reference <- subset(reference,method=="WDSM")
key <- function(x) paste(x$study,x$outcome,x$M)
reference <- reference[match(key(tab),key(reference)),]
stopifnot(max(abs(as.matrix(tab[,c("estimate","SE","lower","upper")])-
  as.matrix(reference[,c("estimate","SE","lower","upper")]))) < 1e-8)
write.csv(tab,file.path(here,"rerun_wdsm_summary.csv"),row.names=FALSE)
print(tab,digits=12)
cat("Verified against the published numerical table. This is not a proof of inference validity.\n")
