# Weighted Double Score Matching

Code and aggregate results for **Where to weight? Estimating population causal
effects with weighted double score matching in complex surveys**.

## Publication files

| Content | Location |
|---|---|
| WDSM estimators and comparison methods | [`R/`](R/) |
| Simulation results, four tables, and manuscript figure | [`Results/Publication/`](Results/Publication/) |
| NHANES and NSDUH results, combined figure, and reported tie sensitivity | [`CaseStudy/Results/Publication/`](CaseStudy/Results/Publication/) |
| Simulation drivers | [`Simulations/`](Simulations/) |
| Case-study preparation and analysis | [`CaseStudy/`](CaseStudy/) |
| Conditionally stabilized estimator from Web Appendix A.9 | [`StabilizedWDSM/`](StabilizedWDSM/) |

The repository contains the publication analyses. Current case-study sample
sizes are 3,783 for NHANES and 17,471 for NSDUH. Participant datasets,
individual fitted objects, and local execution records are not distributed.

## Reproduce the analyses

- [Simulation instructions](Results/Publication/README.md): inputs, execution,
  and regeneration of the published tables and figure.
- [Case-study instructions](CaseStudy/README.md): external data requirements,
  preparation, estimation, and regeneration of the final tables and figure.

Run commands from the repository root and write new results outside it. The
simulation and NSDUH analyses used R 4.4.2; the NHANES analysis used R 4.4.3.
The scripts check required R packages. Figure generation also requires Python
3 with matplotlib. Different dependency versions can affect exact reproduction.

The vendored `dsmatch` routines in `R/dsmatch/` are the subset used by the
publication comparators. Their original author attribution and GPL-3 license
are retained in `R/dsmatch/DESCRIPTION`.
