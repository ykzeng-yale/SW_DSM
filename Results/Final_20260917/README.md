# Final September 17 WDSM simulations

The complete Bouchet rerun passed strict record, provenance, numerical, and publication checks. Recipient-specific randomized tie handling produced **no numerical change from the corrected September 9 simulations**. All 224 main summary rows and 96 stabilized summary rows are exactly equal to that baseline. The preserved [September 9 result package](../Final_20260909/) remains unchanged.

The independent main comparison paired all 32,000 records and 224,000 method results, including input identities and random-number streams. Every estimate, standard error, interval endpoint, and retained bootstrap draw has zero numerical difference. The stabilized comparison also found exact agreement for all 95,928 successful estimates and the same 72 rho rejections. Neither simulation run required randomized boundary allocation. See the [main comparison](verification/full_pairing/comparison_summary.txt), [stabilized comparison](verification/stabilized_pairing/comparison_summary.txt), and [summary comparison](verification/metric_comparison_20260909_20260917.json).

These results retain the earlier bootstrap and score corrections. They do not restore older paper/0727 values. The [manual manuscript guide](MANUSCRIPT_GUIDANCE.md) supplies the remaining main-paper and appendix replacements and the separate application updates. The author's manuscript sources were not edited.

## Scope and inference

The main run covers PATE/PATT, retrospective/prospective sampling, good/poor overlap, and four score-model specifications: 32 cells, each with 1,000 sample replications, seven methods, and WDSM matching ratios M=1,3,5. Bootstrap methods use B=200. All 224,000 requested main method results passed. WDSM uses the B-divisor replication variance; DSM/PGM/PSM use the B−1 bootstrap divisor; SW-PSM uses subclass-cluster sandwich/delta inference. All main intervals are centered normal Wald intervals.

The paired stabilization experiment has 96,000 requested M-specific attempts: 95,928 successes and 72 expected rho rejections. Full-sample primary performance is available for 81 of the 96 settings; the remaining 15 settings are explicitly unavailable and retain their rejection counts. Successful-subset diagnostics are labeled separately. This experiment assesses **point estimates only**. Monte Carlo precision bounds in its figures are not treatment-effect confidence intervals; no stabilized variance or coverage claim is made.

The frozen execution source is `68e14452622ec583e7e70c30ba9185c992033753`. All displayed results come from the complete production outputs, with no pilot records.

## Files to use

| Artifact | Location |
|---|---|
| Eight readable landscape tables: four main and four stabilized | [Combined_Simulation_Tables.pdf](Combined_Simulation_Tables.pdf) |
| Main metrics and strict audit | [main/summary](main/summary/) |
| Four main table fragments and combined LaTeX | [main/Tables](main/Tables/) |
| Main M=5 figures | [main/Figures/Prospective](main/Figures/Prospective/) and [main/Figures/Retrospective](main/Figures/Retrospective/) |
| Main M=1 and M=3 figures | [main/Figures/M1](main/Figures/M1/) and [main/Figures/M3](main/Figures/M3/) |
| Stabilized metrics and strict paired audit | [stabilized/summary](stabilized/summary/) |
| Stabilized tables and figures | [stabilized/performance](stabilized/performance/) |
| Copy-ready manuscript instructions | [MANUSCRIPT_GUIDANCE.md](MANUSCRIPT_GUIDANCE.md) |
| Restore populations/raw records and independently rerender | [REPRODUCE.md](REPRODUCE.md) |
| Full numerical publication validation | [verification.json](verification.json) |
| Artifact integration source/hash mapping | [integration_manifest.json](integration_manifest.json) |
| Compiler, exact LaTeX fragments, logs, page previews, and PDF QA | [reproduction](reproduction/) |

The main figure tree contains 72 files: PNG/PDF versions for all three M values, two designs, two layouts, and three styles. The M=5 paths deliberately omit an `M5/` component. Stabilized performance has three figures in both PNG and PDF formats. Separate visual reviews inspected all 39 actual PNG figures ([M1](verification/visual_review_M1.json), [M3](verification/visual_review_M3.json), [M5](verification/visual_review_M5.json), [stabilized](verification/visual_review_stabilized.json)) and all [eight compiled table pages](verification/visual_review_compiled_tables_landscape.json). Their checks passed. The numerical validator's `visual_review_performed: false` describes that validator's scope; these separate reports document the visual review.

## Raw archive status and integrity

**Multipart raw-archive publication is pending.** The planned GitHub release tag is `tie-corrected-simulations-20260917`; the restore guide clearly marks download commands as applying after publication. This tree already contains the completed numerical summaries, tables, figures, and validation evidence. This result tree omits the large complete-record CSVs and paired-record CSVs. The full paired comparisons remain available under `audit/ties_20260917/`; the scheduled raw archive retains all complete main/stabilized records and saved main bootstrap draws. Exact population assets remain in the unchanged September 9 release.

`ARTIFACT_SHA256SUMS.txt` covers every other file in this result tree. From this directory, verify it with:

```sh
shasum -a 256 -c ARTIFACT_SHA256SUMS.txt
```

Audit reports retain the original absolute staging/cluster paths as provenance; the files listed above are their integrated repository counterparts. Source hashes and the integration manifest connect these locations. Case-study data/results are maintained separately under [CaseStudy/Results/TieCorrection_20260917](../../CaseStudy/Results/TieCorrection_20260917/).
