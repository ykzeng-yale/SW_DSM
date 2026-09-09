# Independent numerical audit of historical PATE point propensity fits

Date: 2026-09-09. Read-only audit of original population and source files. Only audit artifacts were created; canonical R files were not edited by this audit.

## Findings

The historical retrospective good-overlap propensity-score solver is not solving its stated weighted logistic estimating equations. This problem occurs before the bootstrap and changes the matching estimator itself.

The diagnostic recreated sampling with historical `set.seed(2025 + replication)`, using the first 20 samples in each of retrospective/prospective and good/poor overlap, for both correct and misspecified propensity models (160 original model fits, plus 160 stable fits). The first sample's selected unit IDs exactly match the actual Bouchet pilot record (`n=4884`, treated `n=1608`). The retrospective model uses original survey weights; the prospective model uses unit weights, consistent with the corrected prospective point-estimator implementation.

| Design and overlap | Original fits failing convergence | Stable fits failing convergence |
|---|---:|---:|
| Retrospective, good | 40 / 40 | 0 / 40 |
| Retrospective, poor | 0 / 40 | 0 / 40 |
| Prospective, good | 0 / 40 | 0 / 40 |
| Prospective, poor | 0 / 40 | 0 / 40 |

Each row includes 20 samples × two propensity specifications. This is a bounded diagnostic of the first 20 samples, not a measured failure rate across the entire 1,000-sample experiment.

Original default `glm` used its default initialization and 25-iteration limit. For the failed fits, absolute coefficient magnitudes reached 2.59×10^15 and normalized score-equation residuals reached 0.422. These are not legitimate weighted logistic solutions. Maximum fitted-probability differences from the stable solution reached 0.9933. For each of the first two retrospective good samples, every fitted probability was numerically at a boundary.

The stable fit starts every coefficient at zero and allows up to 100 IRLS iterations with a 1e−12 convergence tolerance. For the broad diagnostic, weights were divided by their mean, a common factor that leaves the coefficient estimating equations unchanged. All 160 stable fits converged; maximum absolute coefficient was 1.974 and maximum normalized score-equation residual was 2.06×10^−15. In a separate first-two-sample check of all four design/overlap cells, raw-weight zero-start and normalized-weight zero-start solutions agreed to 1.24×10^−14 in coefficients. Normalized default-start and normalized zero-start solutions agreed to 7.86×10^−13. Thus the failure is numerical initialization, not evidence of separation or a need to change the weighted statistical model in those examined samples.

In the other three design/overlap cells, original default estimates agreed with stable fitted probabilities to at worst 6.77×10^−9. Small numerical differences should still be monitored because matching can be discontinuous.

## Direct link to a reported historical point estimate

A complete M5 point-estimator comparison was run for only the first retrospective good-overlap CorCor sample, with identical sample, prognostic fits, matching algorithm, weight normalization, and sieve specification. The sole changed operation was solving the propensity model with a zero coefficient start rather than the failed default initialization.

- Original point estimate: approximately 0.9015108.
- Historical saved paper point: approximately 0.9015108.
- Original minus saved paper: −1.11×10^−16, demonstrating numerical reproduction of the actual historical record.
- Stable weighted-logistic point estimate: approximately 0.8944403.
- Stable minus original: −0.007070478 (−0.7843% of the original estimate).
- All 4,884 recipients' donor lists changed: 1,608 treated recipients and 3,276 control recipients.
- Original point computation warned about a rank-deficient treated-outcome sieve; the stable computation did not emit that warning in this sample.

This is one observed sample's point-estimate change, not the change in Monte Carlo bias across the entire experiment.

## Implication for rerun validation

A requirement that every corrected point estimate equal the historical result is scientifically indefensible for retrospective good overlap: it would require preserving an unconverged nuisance fit and its resulting matches. A corrected rerun should instead verify identical input population and sampled records, enforce convergence and small weighted score residuals, preserve the stated propensity model and survey-weight equations, and report paired historical-versus-corrected point changes explicitly.

An SE/endpoint-only rewrite cannot repair this point-estimation problem. The corrected point estimate, matching structure, sieve, and bootstrap must be recomputed consistently. Existing historical numbers should remain archived and distinguishable from the corrected outputs.

## Artifacts

- `point_ps_first20.R`: exact bounded diagnostic.
- `point_ps_first20.csv`: per-model solver diagnostics (320 rows).
- `point_ps_first20_coefficients.rds`: all fitted coefficients.
- `point_ps_first20.log`: execution output.
- `point_ps_numerical_diagnostic.R`, `.csv`, `.log`, and `point_ps_numerical_coefficients.rds`: first-two-sample four-solver equivalence check.
- `first_point_impact.R`, `.log`, `.rds`: full first-sample M5 point comparison.

## Audit-source SHA-256

- `point_ps_first20.R`: `dcbb6ea4913c4c3ea22312a8b5f7db80b9b4ee16ecc13d0752893d5a607ddb6e`
- `point_ps_first20.csv`: `618f55704e54442151b96c3c58845abd2427a21f038813a79ae24ddb51efbb7e`
- `point_ps_numerical_diagnostic.R`: `ed30d1743a17dbed5bbd57eaf5a8a67d2922d90f62ef485729afecf3f5b06b35`
- `point_ps_numerical_diagnostic.csv`: `a57c4d83fb6f41367a31def5ea1b4af5580d231fc8d1491facf07068e6ac6f49`
- `first_point_impact.R`: `bfa9700d2029ad664e76c80e038e37af4de574366bdc2e48440edc1f13c366ca`
- `first_point_impact.log`: `6d389129e42f66a90b9f1fa9ee4d473899897d30f1ad67900b4257b296aa61e4`
- Original `0727 Test (SW_DSM)/wdsm_ci_functions.R`: `98c0365b2f7b5d3500212e6b28f39a2234847df3fa478ddde19cf949fa0200a1`

Canonical helper read-only review found no actionable defect in the intended six-covariate point/bootstrap calls: raw weights are preserved, zero coefficients are explicit, and checks cover finite inputs, both weighted treatment arms, convergence, full rank, finite coefficients, unsaturated probabilities, and weighted score-equation residuals. The common-factor normalized solver used in the diagnostic is an independent numerical reference; production uses raw weights. This inspection does not certify all future samples or establish the theoretical validity of the replication method.
