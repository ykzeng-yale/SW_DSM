# PATE bootstrap correction and rerun audit — 2026-09-09

Baseline GitHub commit: `3356769fc3d0805678d7fd927108d4b00c069980`.
Manuscript reference: user-supplied `main (8).tex`; the file has not been edited.

## Which results are in the paper?

The local `0727 Test (SW_DSM)/Doc/generate_tables.R` reproduces the complete saved table text byte-for-byte from `Doc/Results` and `Doc/Results_PATT`. The table, result inputs, and corresponding canonical GitHub copies match. Active manuscript values match these tables. See [paper result lineage](paper_result_lineage.md) and its comparison CSVs.

All 32 result-file hashes match files in the user's Tong storage, `/nfs/roberts/project/pi_gt353/yz2324`:

| Paper input | Cluster family | Result dates (EDT) |
|---|---|---|
| Retrospective PATE, 8 files | `PATE_Retrospective_*_ALLFIXED/*_M135_1000rep` | 2026-04-10 |
| Prospective PATE, 8 files | `PATE_Prospective_*_ALLFIXED/*_M135_1000rep` | 2026-04-13 |
| Retrospective/prospective PATT, 16 files | `PATT_*_10TERM/*_M135_1000rep` | 2026-04-08 |

The Fan Li project area, `/nfs/roberts/project/pi_fl426/yz2324`, contains an earlier `pate_test_20260404` folder, not these production result files. No files were present in the two inspected user scratch areas. All source and result inspections were read-only.

The 32 point/bootstrap PATE core files beside the matching production outputs have the same SHA-256 hashes as their corresponding canonical GitHub source at the baseline commit. Their modification times precede the matching run logs. Example jobs: retrospective good CorCor 7801742 ran April 9 23:33–April 10 01:16; prospective good CorCor 8170654 ran April 13 21:00–22:38. Historical `sacct` returned no records for those jobs; file/log/source evidence is retained instead of inventing scheduler provenance.

The newer `wdsmatch_validation_1000rep` outputs date to April 14. They are not the joint source of the paper's tables. All 96 WDSM point-estimate vectors match the paper inputs, but prospective PATE and PATT intervals differ. The newer prospective PATE bootstrap SEs and endpoints exactly match the older local April 10 ` 2.RData` alternatives, while its point estimates match the April 13 version. The saved cluster package `wdsmatch_0.1.0.tar.gz` retains the reversed match-list bootstrap bug and always uses survey-weighted propensity replication, including when its `sampling` argument is prospective. Installed package version at the historical execution time was not recorded, so the saved package is corroborating source evidence, not a recovered runtime lockfile.

## Confirmed inference issues

1. In the paper-linked PATE code, `matches_0` exists for treated recipients only and `matches_1` for controls only. The old bootstrap reads these at the opposite indices. Every residual-correction branch skips. The draws reduce to the weighted replicated sieve mean difference. This is more than an interval-endpoint issue.
2. All 48,000 saved PATE WDSM intervals are non-Wald; all 48,000 paper-linked PATT WDSM intervals match estimate ± normal critical value × stored SE. The table/plot scripts use saved bounds directly.
3. Old PATE uses percentile quantiles and `sd()` (B−1 divisor). Manuscript lines 1044 and 1047 specify B-divisor replication variance and Wald intervals. B versus B−1 is a finite Monte Carlo convention; at B=200 the SE difference is about 0.25%, much smaller than the omitted residual issue.
4. Historical result objects do not retain bootstrap draws, source hashes, successful B counts, or RNG states. Reconstructing Wald from their old SE is only an endpoint diagnostic, not a corrected-bootstrap result.
5. The first Bouchet pilot exposed a numerical failure in the historical propensity fitting procedure. In the first retrospective good-overlap sample (n=4,884), raw survey weights range from 74.5 to 519.3. Default weighted `glm` initialization fails to converge and produces coefficients around 1e15 and degenerate fitted probabilities; increasing the iteration limit alone does not repair it. Starting the same weighted logistic model at zero coefficients converges, agrees with a normalized-weight solution, and satisfies the weighted score equations. This affects the original point fit as well as bootstrap fits. The stable fit therefore intentionally supersedes historical numerical outputs; equality to a failed historical point fit is not an acceptance criterion.

## Implemented correction

Compute raw original weighted reuse K once from the original matches. For each multinomial vector m, refit propensity/prognostic and bias-correction models and calculate

`sum(m*w*(q1-q0) + m*(2*A-1)*(w+K)*(Y-qA)) / sum(m*w)`.

Retrospective propensity replication uses m*w; prospective uses m. Both prognostic regressions use m, and bias-correction regressions use m*w. No matching is repeated and no replicate-specific donor denominator is formed. Variance is the mean squared deviation of all B draws from their mean. The CI is the original BC point estimate ± qnorm(0.975)×SE. Failed bootstrap draws stop that estimate and are recorded explicitly by the rerun driver.

The correction preserves the mathematical point estimator and joint 10-term sieve, while solving its propensity model from a stable zero-coefficient initialization and checking convergence. Original numerical point estimates can change where the historical fit failed or stopped imprecisely. Affine standardization of the sieve coordinates preserves the fitted span with an intercept when the design is identifiable. That joint sieve uses both prognostic scores, whereas the manuscript describes arm-specific q_z(D_z); this preexisting specification difference remains a separate scientific/documentation issue. The current correction must not be described as proving all manuscript assumptions or all complex-survey design validity.

## Validation and execution

The initial correction passed 134 independent checks under R 4.4.0: hand-calculated unequal-weight reuse and replicate formulas; all-ones replication identity; weight-scaling invariance; unweighted reduction; B-divisor Wald arithmetic; preserved original point estimates/matches in small convergent examples; affine sieve invariance; finite reproducible actual bootstraps; flags/design fitting weights; explicit failure without a CI. Actual-population pilot checks then exposed the additional initialization issue above. Tests and a second pilot are required after that numerical correction; the initial check count is not evidence that the first cluster pilot passed.

After the stable propensity correction, 153 checks passed, including a portable large-weight failure example, equivalence to independently normalized-weight logistic solutions, zero-weight observations, and explicit rejection of failed or numerically saturated fits. On the actual first failed pilot sample, all 600 propensity replication fits (200 draws for each M) converged in five iterations; maximum normalized score residual was 1.83e−14. A separate [point-fit numerical audit](propensity_numerical_audit.md) found all 40 examined retrospective good-overlap historical fits failed among the first 20 samples, while all 160 stable fits across the four design/overlap cells converged. These are bounded diagnostics, not a 1,000-sample failure-rate estimate.

Bouchet pilot 25688712 finished with 24 successful and 8 failed sample records, all failures in retrospective good overlap. Its results remain retained. The second pilot, 25689465, uses the stable source commit `f1e4d83`, five sample replications per cell, all 16 cells, M={1,3,5}, and B=200. Its outcome is recorded separately in `cluster_execution.json`; submission alone is not a pass.

The second pilot completed and passed strict record, hash, fitting-diagnostic, B-divisor, and Wald endpoint checks: 80/80 sample records, 240/240 estimates, all 48,000 requested bootstrap draws, and no recorded warnings or failures. All 60 retrospective good-overlap pilot point estimates changed, as expected after fixing the failed nuisance fits; the other 180 point estimates agree with their historical values within 1e−8. The pilot is not a Monte Carlo coverage validation. Full PATE production array `25689737` has been submitted with 1,000 samples per cell and remains a separate, unfinished run until all output checks pass.

The new PATE-only driver retains sample seeds 2025+i and uses separately declared bootstrap seeds 1000000+10*i+M. These produce the same sampled datasets but are new bootstrap draws: old comparators consumed an unrecorded shared RNG stream. The driver saves every draw, sampled unit IDs, code/data/config/runtime hashes, session information, and per-estimate failures. Resume requires matching provenance. Historical comparator outputs and all original source/results remain separate.

Production target: 16 design/overlap/model cells × 1000 sample replications × M={1,3,5} × B=200. Cluster pilot and production completion are tracked separately; code validation alone is not a completed or validated simulation result.

## Additional PATT findings; not included in the active PATE rerun

The paper-linked PATT retrospective source uses the same raw-weight default-initialization propensity fit and the same sampled records as PATE. The directly observed first-sample numerical failure therefore also applies to that PATT nuisance equation. Prospective PATT uses unweighted point propensity fitting and count-only bootstrap fitting; the specific raw-survey-weight initialization failure is absent there.

PATT's fixed original control-donor reuse, residual direction, and treated-only normalization are structurally correct. Its Wald endpoints are centered correctly, but `sd()` uses B−1. Fitting errors silently substitute original PS, prognostic, or bias-correction predictions, and missing bootstrap values are dropped without explicit failure counts. Thus existing PATT results cannot be described as fully validated or unified merely because their endpoints are Wald. The joint-sieve specification issue also applies. No PATT source was changed or PATT rerun submitted as part of the active PATE correction.
