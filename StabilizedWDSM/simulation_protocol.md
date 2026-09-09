# Frozen paired point-estimator experiment

Protocol version 1, September 9, 2026. Machine-readable specification: `simulation_protocol.json`. Source baseline: main commit `abee4c1`. This experiment evaluates whether **conditional stabilization reduces absolute relative bias** relative to the corrected original self-normalized WDSM on the same samples, fitted models, and match sets. It does not change the original WDSM estimator, its production jobs, the 0727 archive, or the manuscript's current results.

Only point performance is studied. There are no stabilized treatment-effect standard errors, confidence intervals, or coverage results in this protocol.

## Fixed grid and population

The grid is exactly the corrected baseline's 32 cells, with M=1,3,5 in each cell: **32,000 sampled data sets and 96,000 requested stabilized point estimates** in production. A five-replication pilot per cell contains 160 data sets and 480 requested estimates. The original counterpart is recomputed only to obtain the identical fitted point objects and is checked against completed baseline records.

| Array | Estimand | Sampling | Overlap | PS / PG | M | Production N |
|---:|---|---|---|---|---|---:|
| 0 | PATE | retrospective | good | CorCor | 1, 3, 5 | 1,000 |
| 1 | PATE | retrospective | good | MisCor | 1, 3, 5 | 1,000 |
| 2 | PATE | retrospective | good | CorMis | 1, 3, 5 | 1,000 |
| 3 | PATE | retrospective | good | MisMis | 1, 3, 5 | 1,000 |
| 4 | PATE | retrospective | poor | CorCor | 1, 3, 5 | 1,000 |
| 5 | PATE | retrospective | poor | MisCor | 1, 3, 5 | 1,000 |
| 6 | PATE | retrospective | poor | CorMis | 1, 3, 5 | 1,000 |
| 7 | PATE | retrospective | poor | MisMis | 1, 3, 5 | 1,000 |
| 8 | PATE | prospective | good | CorCor | 1, 3, 5 | 1,000 |
| 9 | PATE | prospective | good | MisCor | 1, 3, 5 | 1,000 |
| 10 | PATE | prospective | good | CorMis | 1, 3, 5 | 1,000 |
| 11 | PATE | prospective | good | MisMis | 1, 3, 5 | 1,000 |
| 12 | PATE | prospective | poor | CorCor | 1, 3, 5 | 1,000 |
| 13 | PATE | prospective | poor | MisCor | 1, 3, 5 | 1,000 |
| 14 | PATE | prospective | poor | CorMis | 1, 3, 5 | 1,000 |
| 15 | PATE | prospective | poor | MisMis | 1, 3, 5 | 1,000 |
| 16 | PATT | retrospective | good | CorCor | 1, 3, 5 | 1,000 |
| 17 | PATT | retrospective | good | MisCor | 1, 3, 5 | 1,000 |
| 18 | PATT | retrospective | good | CorMis | 1, 3, 5 | 1,000 |
| 19 | PATT | retrospective | good | MisMis | 1, 3, 5 | 1,000 |
| 20 | PATT | retrospective | poor | CorCor | 1, 3, 5 | 1,000 |
| 21 | PATT | retrospective | poor | MisCor | 1, 3, 5 | 1,000 |
| 22 | PATT | retrospective | poor | CorMis | 1, 3, 5 | 1,000 |
| 23 | PATT | retrospective | poor | MisMis | 1, 3, 5 | 1,000 |
| 24 | PATT | prospective | good | CorCor | 1, 3, 5 | 1,000 |
| 25 | PATT | prospective | good | MisCor | 1, 3, 5 | 1,000 |
| 26 | PATT | prospective | good | CorMis | 1, 3, 5 | 1,000 |
| 27 | PATT | prospective | good | MisMis | 1, 3, 5 | 1,000 |
| 28 | PATT | prospective | poor | CorCor | 1, 3, 5 | 1,000 |
| 29 | PATT | prospective | poor | MisCor | 1, 3, 5 | 1,000 |
| 30 | PATT | prospective | poor | CorMis | 1, 3, 5 | 1,000 |
| 31 | PATT | prospective | poor | MisMis | 1, 3, 5 | 1,000 |

`CorCor`, `MisCor`, `CorMis`, and `MisMis` refer to propensity/prognostic specifications in that order. Every formula includes X1,…,X6. Correct specification adds X1:X2; misspecification omits it. The PS response is A and PG response is the observed Y. Neither omission changes the sampling law or the truth.

Use the existing million-unit population objects `SuperPopGen_{GoodOverlap,PoorOverlap}_AllinOne_0118_2025[[1]]`; do not regenerate them. Each has ten strata of 100,000 units. The verified HPC input directory is `/nfs/roberts/project/pi_gt353/yz2324/WDSM_Final_Aligned_20260909/data`.

- Good-overlap population SHA-256: `f31b8094adccd6328f147308c8ef4de6df8f95ae19d49d3067ad2e0fabe17133`.
- Poor-overlap population SHA-256: `05651582c7e84792182b9cc44c6e02e12fff292b02e2bd0234794ffaf1964b4e`.

These hashes were read from the baseline's retained Bouchet manifests. The current shared-core SHA-256 remains `cfc520662596c44b221a53a810254436ef36ae633a466b42e8c2109876c9c15f`, identical to that baseline. All three fixed source hashes are recorded in the JSON. Each actual run must additionally freeze its driver/adapter/protocol and actual runtime hashes.

## Identical sampling, seeds, and targets

Use RNG kinds `Mersenne-Twister`, `Inversion`, `Rejection` and **sample seed 2025 + replication**, for replications 1–1000. The baseline cluster sampling runtime was R 4.4.2 and sampling 2.10. Preserve the actual runtime in the new manifest and check ordered sample IDs directly; matching a seed string alone is insufficient evidence of identical samples.

Under retrospective sampling, independently include each population unit with probability `exp(lp)/(1+exp(lp))`, where

```
lp = log((5000/N)/(1-5000/N)) + log(.9)*A
   + log(1.05)*X1 + log(1.10)*X2 + log(1.15)*X3
   + log(1.10)*X4 + log(1.05)*X5 + log(1.10)*X6.
```

Use `rbinom(N,1,probability)==1`, retain population row order, and assign weight 1/probability. The sample size is random; do not resample to force exactly 5,000 units.

Under prospective sampling, retain the baseline `sampling::mstage` call with stages stratified/cluster/unit, ten stratum sizes 100,000, five clusters per stratum, and final per-stratum totals 850,750,700,650,600,400,350,300,250,150, each split equally among its five sampled clusters. Use the original third-stage `getdata` row order and weight 1/Prob. The total is 5,000 sampled units.

For fixed design, overlap and replication, ordered population IDs and sampling weights must agree across both estimands, all four specifications and all three M values. The truths are the fixed-population mean of Y1−Y0 for PATE and its fixed-population mean among A=1 for PATT. The treated-sample mean is not the PATT truth.

## What changes and what stays paired

The original nuisance/matching implementation is the updated shared core. Retrospective PS fits use survey weights; prospective PS fits do not. PG fits are unweighted within arm. Matching uses probability propensity scores, own-arm prognostic scores, pooled unweighted component standardization, squared Euclidean distances, replacement, and stable radix donor ordering. Each outcome-bias regression is the original survey-weighted own-arm complete quadratic. PATE needs both arms' auxiliary fits; PATT needs the control auxiliary fits only.

The adapter calls `wdsm_final(..., B=2, bootstrap_counts=matrix(1,n,2), keep_point=TRUE)` solely to expose its official point fit and match sets. **These are two deterministic all-one identity vectors, not bootstrap replications. Their artificial zero variance, SEs, and confidence limits must be discarded and never interpreted.** No random draws are consumed. It then calls the existing `wdsm_stabilized_from_fit()` with that official fit, retaining the original estimate even if the new rho fit fails. The adapter's reconstructed self-normalized estimate must agree with its original counterpart within `1e-10*(1+abs(original_estimate))`; comparison to independently stored baseline estimates additionally records source/sample identity, tolerance, and observed difference.

The only point-estimator change is the donor residual correction. For a missing arm-z outcome,

\[
\widetilde Y_i(z)=\widehat m_z(D_{z,i})+
\frac{1}{M}\sum_{j\in\mathcal J_z(i)}
\frac{W_j}{\widehat\rho_z(D_{z,j})}\{Y_j-\widehat m_z(D_{z,j})\}.
\]

Rho is evaluated at donor j, the multiplier applies to the whole residual, and there is no additional normalization by a match set's stabilized-weight sum. Observed outcomes and the original survey-weighted outer PATE/PATT averages are unchanged. In particular, the stabilizer does not cancel at M=1.

## Frozen rho specification and failures

The working model is **rho_degree=2**: unweighted least squares of W/mean(W) on the full quadratic of the observed arm's standardized double score, multiplied back by the pooled mean W. It is not a survey-weighted regression. Exactly constant weights within an arm use the exact constant submodel.

A quadratic least-squares fit to positive weights is not positivity constrained. The current estimator rejects nonfinite or nonpositive predictions on **all observations of each required observed arm**, including observations never selected as donors; it also rejects rank-deficient fits. A positive but very small rho can still yield a large multiplier. Neither positive observed weights nor a successful synthetic smoke test establishes a small rejection rate.

No clipping, trimming, silent fallback, replacement data sets, or post-result degree selection is allowed in this experiment. The default fixed quadratic is a practical working model, not the shrinking-bandwidth ball-kernel implementation in the appendix's feasible-consistency argument. Any alternative positive-link, kernel, or different-degree estimator would be a separately declared experiment.

The pilot and full run must retain the rho arm, sample size, rank/failure, nonpositive/nonfinite counts, and raw observed-arm prediction range/quantiles before rejection. Successful fits additionally record W/rho and local stabilizer-mass tails, imputation/reuse identity error, and original-counterpart discrepancy. Coefficients and response scaling are useful supporting diagnostics. Rho fitting does not depend on M: three repeated-M failures on one data set are not three independent sampling failures. The same control-rho failure also affects PATE and PATT on identical data/specifications. Report both requested cell/M failure counts and unique sampled-data/specification failure counts.

A completed experiment may contain genuine rho rejections; these are empirical outcomes, not missing records. Pipeline, baseline-pairing, and unexpected errors are separate blocking problems. Preserve the full requested denominator (1,000) for failure rates. Primary full-run bias comparisons require all 1,000 paired estimator successes. If some rho fits fail, optional success-only performance must be separately labeled conditional on success, report its paired N, and compare the original method on that exact subset. It must not replace the unconditional 1,000-run performance claim.

## Primary comparison and Monte Carlo precision

For each of the 96 cell/M configurations, primary outcomes are:

\[
\operatorname{RB}_k=100\{\overline{\widehat\tau}_k-\tau\}/|\tau|,
\qquad \operatorname{ARB}_k=|\operatorname{RB}_k|,
\qquad \operatorname{Reduction}=\operatorname{ARB}_{original}-\operatorname{ARB}_{stabilized}.
\]

Positive reduction means smaller absolute relative bias. Absolute relative bias is the absolute value of the mean bias, **not the mean absolute error across replications**. Report signed relative biases too, so movement through zero is visible. Use paired samples for the comparison; Monte Carlo SD, RMSE, and rejection frequency are secondary outcomes.

With all 1,000 pairs, report the signed relative-bias difference and its Monte Carlo SE, `100*sd(stabilized-original)/sqrt(N)/abs(truth)`. This measures simulation precision, not a causal-estimator SE.

For uncertainty in absolute-bias reduction, avoid a naive derivative of absolute value at zero. Use the conservative approximate Monte Carlo interval specified in the JSON: construct simultaneous Bonferroni t intervals for the two signed biases using t(.9875,N−1), transform each interval into its minimum/maximum possible absolute value, and subtract the resulting stabilized range from the original range. An interval crossing zero has minimum absolute value zero. This gives Monte Carlo uncertainty for the **experiment's bias comparison**; it is not a Wald or percentile confidence interval for a stabilized treatment-effect estimate.

This protocol alone does not supply a rejection rate, prove stabilization reduces bias, or validate stabilized inference. Those conclusions must be limited to the completed, audited experiment and its stated working model.
