#!/usr/bin/env Rscript
# Complete local entrypoint: full raw reconstruction, all 17 primary rows,
# eight paired WDSM controls, independent verification, and publication figure.
args<-commandArgs(trailingOnly=TRUE)
if(length(args)!=1L)stop("Usage: Rscript --vanilla CaseStudy/reproduce_tie_correction.R NEW_OUTPUT_DIRECTORY")
repo<-normalizePath(getwd(),mustWork=TRUE);out<-path.expand(args[1L])
if(dir.exists(out)&&length(list.files(out,all.files=TRUE,no..=TRUE)))stop("Choose a new output directory")
commit<-system2("git",c("rev-parse","HEAD"),stdout=TRUE)
stopifnot(length(commit)==1L,grepl("^[0-9a-f]{40}$",commit))
if(system2("git",c("diff","--quiet","HEAD","--","R","CaseStudy"))!=0L)
  stop("Commit the source changes before a reproducible full run")
dir.create(out,recursive=TRUE,showWarnings=FALSE);out<-normalizePath(out)
source(file.path(repo,"CaseStudy","prepare_from_raw.R"))
prepare_case_raw(repo,file.path(out,"raw_reconstruction"))
for(file in c("nhanes_clean_3790.rds","nsduh_rebuilt_17471.rds")) {
  fresh<-readRDS(file.path(out,"raw_reconstruction",file))
  frozen<-readRDS(file.path(repo,"CaseStudy","data_preparation_20260917",file))
  stopifnot(identical(fresh,frozen))
}
Sys.setenv(WDSM_REPO=repo,WDSM_CODE_COMMIT=commit,CASE_OUTPUT_DIR=file.path(out,"records"),
  OMP_NUM_THREADS="1",OPENBLAS_NUM_THREADS="1",MKL_NUM_THREADS="1",
  VECLIB_MAXIMUM_THREADS="1",BLIS_NUM_THREADS="1")
rscript<-file.path(R.home("bin"),"Rscript")
for(task in 0:15) {
  Sys.setenv(CASE_TASK_ID=task)
  status<-system2(rscript,c("--vanilla",shQuote(file.path(repo,"CaseStudy","rerun_tie_correction.R"))),
    stdout=file.path(out,sprintf("task_%02d.log",task)),stderr="")
  if(status!=0L)stop("Case task ",task," failed; inspect its log and saved error record")
}
status<-system2(rscript,c("--vanilla",shQuote(file.path(repo,"CaseStudy","assemble_tie_correction.R")),
  shQuote(file.path(out,"records")),shQuote(file.path(out,"publication"))))
if(status!=0L)stop("Independent assembly failed")
status<-system2(Sys.getenv("PYTHON","python3"),c(shQuote(file.path(repo,"CaseStudy","Figures","plot_corrected_case_studies.py")),
  "--results",shQuote(file.path(out,"publication","results.csv")),
  "--output",shQuote(file.path(out,"publication","Figures"))))
if(status!=0L)stop("Figure generation failed")
cat("Complete raw-data reconstruction, 17 primary estimates, paired controls, and numerical verification saved to:",out,"\n")
