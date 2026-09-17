# Case-specific covariate dimensions; original comparator algorithms and seeds.
case_comparator <- function(d, vars, method, study, repo, B=200L) {
  ledger <- new.env(parent=emptyenv())
  ledger$glm_fits <- ledger$lm_fits <- ledger$rank_deficient_lm <- 0L
  ledger$bootstrap_draws <- numeric()
  warnings_seen <- character()
  answer <- withCallingHandlers({
    if(method != "SWPSM") {
      vendor <- .comparator_final_vendor(repo,B,ledger)
      X <- as.matrix(d[,vars])
      args <- list(Y=d$Y,X=X,A=d$A,method=switch(method,DSM="dsm",PSM="ps",PGM="pg"),
        cov.balance=FALSE,varest=TRUE,boots=B,mc=FALSE,ncpus=1L)
      if(method %in% c("DSM","PSM")) args$model.ps <- "logit"
      if(method=="DSM" || (method=="PGM" && study=="NSDUH")) {
        args$model.pg <- "linpred"; args$lp.pg <- X
      } else if(method=="PGM") args$model.pg <- "glm"
      fit <- do.call(vendor$dsmatchATE,args)
      estimate <- as.numeric(fit[[switch(method,DSM="est.ds",PSM="est.ps",PGM="est.pg")]])
      variance <- as.numeric(fit$bootvar)
      draws <- ledger$bootstrap_draws
      stopifnot(length(draws)==B,all(is.finite(draws)),
        abs(variance-var(draws))<1e-12*(1+variance))
      z <- 1.96 # Retain the original comparator reporting constant.
      list(estimate=estimate,SE=sqrt(variance),lower=estimate-z*sqrt(variance),
        upper=estimate+z*sqrt(variance),draws=draws,divisor=B-1L,
        inference="Wald; original dsmatch fixed-reuse bootstrap; B-1 variance divisor")
    } else {
      df <- d[,c("Y","A",vars)]
      df$sw <- d$survey_weight*nrow(d)/sum(d$survey_weight)
      m <- MatchIt::matchit(reformulate(vars,"A"),data=df,method="full",distance="glm",
        link="logit",s.weights=df$sw,estimand="ATE",include.obj=TRUE)
      ps <- m$model
      if(is.null(ps) && inherits(m$obj,"glm")) ps <- m$obj
      stopifnot(inherits(ps,"glm"),isTRUE(ps$converged),all(is.finite(ps$coefficients)),
        all(is.finite(m$distance)),all(m$distance>0 & m$distance<1))
      md <- MatchIt::match.data(m,data=df,include.s.weights=TRUE)
      stopifnot(nrow(md)==nrow(df),all(is.finite(md$weights)&md$weights>0),!anyNA(md$subclass))
      formula <- as.formula(paste("Y ~ A * (",paste(vars,collapse=" + "),")"))
      fit <- lm(formula,data=md,weights=weights)
      stopifnot(all(is.finite(fit$coefficients)))
      contrast <- marginaleffects::avg_comparisons(fit,variables="A",vcov=~subclass,wts="sw")
      list(estimate=as.numeric(contrast$estimate),SE=as.numeric(contrast$std.error),
        lower=as.numeric(contrast$conf.low),upper=as.numeric(contrast$conf.high),
        draws=numeric(),divisor=NA_integer_,subclasses=length(unique(md$subclass)),
        inference="Normal Wald; matched-subclass cluster covariance; survey weights combined once")
    }
  },warning=function(w) {
    message <- conditionMessage(w)
    if(!grepl("non-integer #successes in a binomial glm",message,fixed=TRUE))
      stop("Unexpected comparator warning: ",message)
    warnings_seen <<- c(warnings_seen,message)
    invokeRestart("muffleWarning")
  })
  stopifnot(all(is.finite(unlist(answer[c("estimate","SE","lower","upper")]))),answer$SE>=0)
  answer$warnings <- unique(warnings_seen)
  answer$nuisance_checks <- as.list(ledger)[c("glm_fits","lm_fits","rank_deficient_lm")]
  answer
}
