#!/usr/bin/env Rscript
# Reconstruct the final NHANES and NSDUH publication samples from external data.
prepare_case_raw <- function(data_dir = Sys.getenv("WDSM_CASE_DATA_DIR"), output) {
  if (!nzchar(data_dir)) stop("Set WDSM_CASE_DATA_DIR to the external source-data directory")
  data_dir <- normalizePath(data_dir, mustWork = TRUE)
  source_path <- function(study, filename) {
    candidates <- c(file.path(data_dir, filename), file.path(data_dir, study, "data", "raw", filename))
    available <- candidates[file.exists(candidates)]
    if (!length(available)) stop("Missing external source file: ", filename)
    available[[1L]]
  }
  if (dir.exists(output) && length(list.files(output,all.files=TRUE,no..=TRUE)))
    stop("Choose a new preparation output directory")
  dir.create(output,recursive=TRUE,showWarnings=FALSE)
  output <- normalizePath(output,mustWork=TRUE)
  repo <- normalizePath(Sys.getenv("WDSM_REPO",getwd()),mustWork=TRUE)
  if(identical(output,repo)||startsWith(output,paste0(repo,.Platform$file.sep)))
    stop("Use an output directory outside the repository; prepared files contain participant data")
  nh <- new.env(); ns <- new.env()
  nh_path <- source_path("NHANES", "nhanes_2007_2018.rda")
  ns_path <- source_path("NSDUH", "NSDUH_2023.Rdata")
  expected <- c("affadc09f1c6390c5e546281cae5bd08","a2736da9213ec34c0717475dcb96c5a0")
  stopifnot(identical(unname(tools::md5sum(c(nh_path,ns_path))),expected))
  load(nh_path,nh); load(ns_path,ns)
  raw_nh <- as.data.frame(nh$nhanes_2007_2018)
  raw_ns <- as.data.frame(ns$data)
  stopifnot(nrow(raw_nh)==59842L,ncol(raw_nh)==1048L,
            nrow(raw_ns)==56705L,ncol(raw_ns)==2636L)
  covariates <- c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi","smq020")
  needed <- c("lbxgh","sld012",covariates,"wtmec2yr")
  # Preserve all substantive category choices; only refused/unknown are missing.
  cleaned <- raw_nh
  missing_codes <- list(diq010=c(7,9),smq020=c(7,9),dmdeduc2=c(7,9))
  # SLD012 is derived: cycle 9 permits 2..14.5; cycle 10 permits 2..14.
  # In cycle 10, 2 and 14 are valid bottom/top-coded categories.
  stopifnot(all(is.na(raw_nh$sld012) |
    (raw_nh$sddsrvyr==9 & raw_nh$sld012>=2 & raw_nh$sld012<=14.5) |
    (raw_nh$sddsrvyr==10 & raw_nh$sld012>=2 & raw_nh$sld012<=14)))
  for (v in names(missing_codes)) {
    cleaned[[v]][cleaned[[v]] %in% missing_codes[[v]]] <- NA_real_
  }
  keep <- !is.na(cleaned$sld012) & !is.na(cleaned$lbxgh) &
    cleaned$ridageyr>=40 & cleaned$ridageyr<=70 & !is.na(cleaned$diq010) & cleaned$diq010!=1
  keep[is.na(keep)]<-FALSE
  analytic <- cleaned[keep,]
  analytic <- analytic[complete.cases(analytic[,needed]),]
  keep_columns <- unique(c("seqn","sddsrvyr","sdmvpsu","sdmvstra","diq010",needed))
  analytic <- as.data.frame(lapply(analytic[,keep_columns],as.numeric))
  analytic$Y<-analytic$lbxgh;analytic$A<-as.numeric(analytic$sld012<7);analytic$survey_weight<-analytic$wtmec2yr
  raw <- raw_nh[match(analytic$seqn,raw_nh$seqn),]
  stopifnot(identical(as.numeric(raw$seqn),analytic$seqn))
  analytic$smoking_status <- ifelse(analytic$smq020==2,0,
    ifelse(raw$smq040==3,1,ifelse(raw$smq040 %in% 1:2,2,NA)))
  stopifnot(!anyNA(analytic$smoking_status))
  # Exclude recorded pregnancies only; structural/unreleased blanks are retained.
  remove <- raw$ridexprg %in% 1
  stopifnot(sum(remove)==7L)
  analytic <- analytic[!remove,]
  analytic$survey_weight <- analytic$wtmec2yr/2
  stopifnot(nrow(analytic)==3783L,sum(analytic$A)==1001L)
  saveRDS(analytic,file.path(output,"nhanes_publication_3783.rds"),version=2)
  # Preserve the 27-column NSDUH schema and source row order.
  raw_ns$in_analytic_sample <- raw_ns$AGE3 %in% 4:7
  age <- raw_ns$IRMJAGE
  raw_ns$early_mj_use <- ifelse(!is.na(age)&age<15,1,
    ifelse(!is.na(age)&((age>=15&age<900)|age==991),0,NA_real_))
  columns <- c("QUESTID2", "ANALWT2_C", "VESTR_C", "VEREP", "AGE3", "CATAGE",
    "in_analytic_sample", "IRMJAGE", "early_mj_use", "AMIPY", "SMIPY",
    "MMIPY", "LMIPY", "IRAMDEYR", "IRSUICTHNK", "IRSEX", "NEWRACE2",
    "IRFAMIN3", "ANYEDUC3", "COUTYP4", "IRALCAGE", "ALCEVER", "CIGEVER",
    "MILTPARNT", "NOMARR2")
  stopifnot(all(columns %in% names(raw_ns)))
  rebuilt <- raw_ns[raw_ns$in_analytic_sample & !is.na(raw_ns$early_mj_use),columns]
  rebuilt$IRSEX_label<-factor(rebuilt$IRSEX,levels=c(1,2),labels=c("Male","Female"))
  rebuilt$treatment_label<-factor(rebuilt$early_mj_use,levels=c(0,1),labels=c("Control (≥15 or never)","Early use (<15)"))
  stopifnot(nrow(rebuilt)==17471L,ncol(rebuilt)==27L)
  stopifnot(all(complete.cases(rebuilt[,c("AMIPY","SMIPY","early_mj_use","ANALWT2_C")])) )
  saveRDS(rebuilt,file.path(output,"nsduh_rebuilt_17471.rds"),version=2)
  report <- data.frame(study=c("NHANES","NSDUH"),raw_n=c(nrow(raw_nh),nrow(raw_ns)),
    raw_columns=c(ncol(nh$nhanes_2007_2018),ncol(ns$data)),
    analysis_n=c(nrow(analytic),nrow(rebuilt)),
    n_treated=c(sum(analytic$A),sum(rebuilt$early_mj_use)),
    source_md5=unname(tools::md5sum(c(nh_path,ns_path))))
  write.csv(report,file.path(output,"sample_construction_verification.csv"),row.names=FALSE)
  print(report)
  invisible(list(nhanes=analytic,nsduh=rebuilt,report=report))
}
if (sys.nframe()==0L) {
  args<-commandArgs(trailingOnly=TRUE)
  if(length(args)!=1L)stop("Usage: Rscript CaseStudy/prepare_from_raw.R NEW_OUTPUT_DIRECTORY")
  prepare_case_raw(output=args[1L])
}
