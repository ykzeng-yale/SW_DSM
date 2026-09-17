#!/usr/bin/env Rscript
# Reconstruct the original samples from the complete local source datasets,
# then apply the explicitly documented NHANES missing-response correction.
prepare_case_raw <- function(repo = getwd(), output = file.path(repo,"CaseStudy","data_preparation_20260917")) {
  if (dir.exists(output) && length(list.files(output,all.files=TRUE,no..=TRUE)))
    stop("Choose a new preparation output directory")
  dir.create(output,recursive=TRUE,showWarnings=FALSE)
  nh <- new.env(); ns <- new.env()
  nh_path <- file.path(repo,"CaseStudy","NHANES","data","raw","nhanes_2007_2018.rda")
  ns_path <- file.path(repo,"CaseStudy","NSDUH","data","raw","NSDUH_2023.Rdata")
  expected <- c("affadc09f1c6390c5e546281cae5bd08","a2736da9213ec34c0717475dcb96c5a0")
  stopifnot(identical(unname(tools::md5sum(c(nh_path,ns_path))),expected))
  load(nh_path,nh); load(ns_path,ns)
  raw_nh <- as.data.frame(nh$nhanes_2007_2018)
  raw_ns <- as.data.frame(ns$data)
  stopifnot(nrow(raw_nh)==59842L,ncol(raw_nh)==1048L,
            nrow(raw_ns)==56705L,ncol(raw_ns)==2636L)
  covariates <- c("ridageyr","riagendr","ridreth1","dmdeduc2","indfmpir","bmxbmi","smq020")
  needed <- c("lbxgh","sld012",covariates,"wtmec2yr")
  age_sleep <- !is.na(raw_nh$sld012) & !is.na(raw_nh$lbxgh) &
    raw_nh$ridageyr>=40 & raw_nh$ridageyr<=70 & !is.na(raw_nh$diq010) & raw_nh$diq010!=1
  age_sleep[is.na(age_sleep)] <- FALSE
  historical <- raw_nh[age_sleep,]
  historical <- historical[complete.cases(historical[,needed]),]
  original <- new.env()
  load(file.path(repo,"CaseStudy","NHANES","data","WDSM_M1_M3_M5_ANALYSIS_10.rda"),original)
  stopifnot(nrow(historical)==3793L)
  for (v in c("seqn",needed,"diq010","sddsrvyr"))
    stopifnot(identical(as.numeric(historical[[v]]),as.numeric(original$data_prep[[v]])))
  # Preserve all substantive category choices; only refused/unknown are missing.
  cleaned <- raw_nh
  exclusions <- list()
  missing_codes <- list(diq010=c(7,9),smq020=c(7,9),dmdeduc2=c(7,9))
  # SLD012 is derived: cycle 9 permits 2..14.5; cycle 10 permits 2..14.
  # In cycle 10, 2 and 14 are valid bottom/top-coded categories.
  stopifnot(all(is.na(raw_nh$sld012) |
    (raw_nh$sddsrvyr==9 & raw_nh$sld012>=2 & raw_nh$sld012<=14.5) |
    (raw_nh$sddsrvyr==10 & raw_nh$sld012>=2 & raw_nh$sld012<=14)))
  for (v in names(missing_codes)) {
    exclusions[[v]] <- data.frame(variable=v,code=missing_codes[[v]],
      count_in_old_analytic=vapply(missing_codes[[v]],function(code)sum(historical[[v]]==code,na.rm=TRUE),integer(1)))
    cleaned[[v]][cleaned[[v]] %in% missing_codes[[v]]] <- NA_real_
  }
  keep <- !is.na(cleaned$sld012) & !is.na(cleaned$lbxgh) &
    cleaned$ridageyr>=40 & cleaned$ridageyr<=70 & !is.na(cleaned$diq010) & cleaned$diq010!=1
  keep[is.na(keep)]<-FALSE
  analytic <- cleaned[keep,]
  analytic <- analytic[complete.cases(analytic[,needed]),]
  stopifnot(nrow(analytic)==3790L,sum(analytic$diq010==3)==167L,
    all(analytic$seqn %in% historical$seqn),length(setdiff(historical$seqn,analytic$seqn))==3L)
  keep_columns <- unique(c("seqn","sddsrvyr","sdmvpsu","sdmvstra","diq010",needed))
  analytic <- as.data.frame(lapply(analytic[,keep_columns],as.numeric))
  analytic$Y<-analytic$lbxgh;analytic$A<-as.numeric(analytic$sld012<7);analytic$survey_weight<-analytic$wtmec2yr
  saveRDS(analytic,file.path(output,"nhanes_clean_3790.rds"),version=2)
  write.csv(do.call(rbind,exclusions),file.path(output,"nhanes_missing_codes.csv"),row.names=FALSE)
  write.csv(data.frame(seqn=setdiff(historical$seqn,analytic$seqn)),
    file.path(output,"nhanes_excluded_public_ids.csv"),row.names=FALSE)
  # Reconstruct all 27 fields in the saved NSDUH extract, in original row order.
  raw_ns$in_analytic_sample <- raw_ns$AGE3 %in% 4:7
  age <- raw_ns$IRMJAGE
  raw_ns$early_mj_use <- ifelse(!is.na(age)&age<15,1,
    ifelse(!is.na(age)&((age>=15&age<900)|age==991),0,NA_real_))
  original_ns <- as.data.frame(readRDS(file.path(repo,"CaseStudy","NSDUH","data","complete_case_data.rds")))
  columns <- setdiff(names(original_ns),c("IRSEX_label","treatment_label"))
  stopifnot(all(columns %in% names(raw_ns)))
  rebuilt <- raw_ns[raw_ns$in_analytic_sample & !is.na(raw_ns$early_mj_use),columns]
  rebuilt$IRSEX_label<-factor(rebuilt$IRSEX,levels=c(1,2),labels=c("Male","Female"))
  rebuilt$treatment_label<-factor(rebuilt$early_mj_use,levels=c(0,1),labels=c("Control (≥15 or never)","Early use (<15)"))
  stopifnot(nrow(rebuilt)==17471L,ncol(rebuilt)==27L)
  for(v in columns) stopifnot(identical(as.numeric(rebuilt[[v]]),as.numeric(original_ns[[v]])))
  for(v in c("IRSEX_label","treatment_label"))
    stopifnot(identical(as.character(rebuilt[[v]]),as.character(original_ns[[v]])))
  stopifnot(all(complete.cases(rebuilt[,c("AMIPY","SMIPY","early_mj_use","ANALWT2_C")])) )
  saveRDS(rebuilt,file.path(output,"nsduh_rebuilt_17471.rds"),version=2)
  report <- data.frame(study=c("NHANES","NSDUH"),raw_n=c(nrow(raw_nh),nrow(raw_ns)),
    raw_columns=c(ncol(nh$nhanes_2007_2018),ncol(ns$data)),historical_n=c(nrow(historical),nrow(original_ns)),
    rebuilt_historical_values_and_order_match=TRUE,corrected_n=c(nrow(analytic),nrow(rebuilt)),
    corrected_treated=c(sum(analytic$A),sum(rebuilt$early_mj_use)),
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
