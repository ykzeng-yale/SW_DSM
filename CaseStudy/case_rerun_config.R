# Immutable input identities and unchanged published five-fit protocol.
# Exact original input files are included in each study's data/ directory.
case_rerun_config <- list(
  version = "case_numerical_safeguards_20260909",
  baseline_commit = "3356769fc3d0805678d7fd927108d4b00c069980",
  B = 200L, alpha = 0.05, seed = 2024L,
  RNGkind = c("Mersenne-Twister", "Inversion", "Rejection"),
  nhanes_input = list(filename = "WDSM_M1_M3_M5_ANALYSIS_10.rda",
    md5 = "73015527928dab45f090aa3b4a161fa5",
    sha256 = "68c588a1d8d6758848e4f0a54f96b1fd020cf412a36864132d3b966d481946b3",
    n = 3793L, M = c(1L, 3L, 5L), outcome = "HbA1c",
    variables = c("ridageyr", "riagendr", "ridreth1", "dmdeduc2", "indfmpir", "bmxbmi", "smq020"),
    prior_sample_sizes = c(12164L, 5876L, 14021L, 14381L, 8973L),
    prior_draws_per_sample = 150L, original_draws_per_M = 50L),
  nsduh_input = list(filename = "complete_case_data.rds",
    md5 = "ea16b35a982e876de0aa2c3eec40a57e",
    sha256 = "cd8158b3a0d9c7f503b254bbc1488e9a22689a79b132f670bdd2a5afe9890cb9",
    n = 17471L, n_treated = 1877L, M = 5L, outcomes = c("AMIPY", "SMIPY")),
  change = paste("Only numerical safeguards: checked zero-coefficient propensity initialization,",
    "maxit 100, score-residual and saturation diagnostics; reject nonfinite reuse.",
    "Preserve sample, model, weighting, matching, RNG, M, B, fixed reuse and Wald inference.")
)
