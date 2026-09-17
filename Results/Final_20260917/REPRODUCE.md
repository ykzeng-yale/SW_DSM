# Restore and reproduce the September 17 simulation results

The complete main and stabilized numerical summaries and publication artifacts have passed validation and are integrated in this result tree. Main record/draw and stabilized record comparisons with the corrected September 9 baseline passed with exact numerical agreement.

**Multipart archive publication is pending.** The planned release is `tie-corrected-simulations-20260917`. The download commands below apply after that release is published; they are not a claim that the archive is already available. Current tables, figures, the combined landscape PDF, validation records, and compiler reproduction files are available in this tree now.

The release restores the complete main and stabilized runs with recipient-specific
random allocation of boundary ties. The frozen execution source is
`68e14452622ec583e7e70c30ba9185c992033753`. The intended scope is 32 scenarios,
1,000 sampled-data replications per scenario, and WDSM M=1/3/5. Main inference
uses B=200 for the bootstrap methods. Stabilized results concern **point-estimator
performance only**; they do not provide a stabilized treatment-effect variance,
standard error, confidence interval, or coverage estimate.

## 1. Download the tagged source and every multipart archive asset

Access to this private repository and its release assets requires existing
GitHub authorization. Use a filesystem with enough space for the downloaded
compressed parts and the extracted archive; alternatively run the restoration
on Bouchet storage allocated for this purpose. Do not extract into an existing
analysis or baseline folder.

After the release is published, run from a directory of your choosing:

```sh
set -e
set -o pipefail

wdsm_repo="$PWD/SW_DSM_reproduce_20260917"
wdsm_download="$PWD/wdsm-download-20260917"
wdsm_restored="$PWD/wdsm-restored-20260917"
wdsm_recheck="$PWD/wdsm-recheck-20260917"

gh repo clone ykzeng-yale/SW_DSM "$wdsm_repo"
git -C "$wdsm_repo" checkout --detach tie-corrected-simulations-20260917
mkdir "$wdsm_download" "$wdsm_restored" "$wdsm_recheck"
gh release download tie-corrected-simulations-20260917 \
  --repo ykzeng-yale/SW_DSM --dir "$wdsm_download"
```

The archive parts are named `WDSM_Ties_20260917.tar.gz.part000`, `part001`, and
so on, consecutively with three-digit suffixes. All except possibly the final
part are 256 MiB. These files are slices of **one** gzip-compressed tar stream;
they are not independently extractable tarballs. The actual number of parts
comes from the release's `SHA256SUMS.txt`, not from an assumed count.

The archive metadata assets are `SHA256SUMS.txt`, `CONTENT_SHA256SUMS.txt`,
`ARCHIVE_SCOPE.txt`, `ARCHIVE_MEMBERS.txt`, and `CONTENT_VERIFICATION.json`.
The last records the archive creator's successful stream/content check; the
commands below also verify the downloaded bytes independently.

## 2. Verify part hashes, restore all records, and verify extracted contents

On macOS, verify all assets listed in the release checksum file:

```sh
(cd "$wdsm_download" && shasum -a 256 -c SHA256SUMS.txt)
```

On Linux, `sha256sum -c SHA256SUMS.txt` is equivalent. Do not continue after a
missing file or checksum failure. Check that the downloaded part filenames
agree with the manifest and form one uninterrupted sequence:

```sh
python3 - "$wdsm_download" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
entries = [line.split('  ', 1)[1] for line in (p/'SHA256SUMS.txt').read_text().splitlines()]
parts = sorted(n for n in entries if n.startswith('WDSM_Ties_20260917.tar.gz.part'))
expected = [f'WDSM_Ties_20260917.tar.gz.part{i:03d}' for i in range(len(parts))]
actual = sorted(f.name for f in p.glob('WDSM_Ties_20260917.tar.gz.part*'))
assert parts and parts == expected == actual, 'Missing, extra, or nonconsecutive archive parts'
print(f'All {len(parts)} archive parts are present in order.')
PY

cat "$wdsm_download"/WDSM_Ties_20260917.tar.gz.part[0-9][0-9][0-9] \
  | python3 "$wdsm_repo/audit/ties_20260917/verify_archive_stream.py" \
      "$wdsm_download/CONTENT_SHA256SUMS.txt" \
  > "$wdsm_recheck/downloaded_stream_verification.json"

cat "$wdsm_download"/WDSM_Ties_20260917.tar.gz.part[0-9][0-9][0-9] \
  | tar -xzf - -C "$wdsm_restored"

cmp "$wdsm_download/CONTENT_SHA256SUMS.txt" \
    "$wdsm_restored/release_archive/CONTENT_SHA256SUMS.txt"
(cd "$wdsm_restored" && shasum -a 256 -c release_archive/CONTENT_SHA256SUMS.txt)
```

The stream verifier reads and hashes every listed member, checks for missing or
duplicate files, and rejects unexpected regular files. `pipefail` ensures that
a failed read, decompression, or verification stops the sequence. The final
checksum command additionally verifies the restored files on disk. Linux users
can substitute `sha256sum -c` for `shasum -a 256 -c`.

The restored top-level directories are:

| Directory | Contents and role |
|---|---|
| `production_68e1445/` | Main raw RDS records: 32 cells with 1,000 `rep_*.rds` records each, plus manifests and execution metadata |
| `stabilized_production_68e1445/` | Stabilized paired raw RDS records: 32 cells with 1,000 records each, plus manifests and execution metadata |
| `code_68e1445/` | Frozen execution-source snapshot, preserving the original repository contents |
| `final_verified_68e1445/` | Main strict summary, including the complete 224,000-row records CSV |
| `stabilized_final_verified_68e1445/` | Stabilized strict paired summary, including the complete 96,000-row records CSV |
| `publication_68e1445/` | This rerun's main numerical tables and figures |
| `stabilized_publication_68e1445/` | This rerun's stabilized point-performance tables and figures |
| `full_pairing_comparison/` | Saved main September 9 versus September 17 comparison outputs |
| `release_archive/` | Embedded content checksum manifest and archive scope record |

**Use `publication_68e1445/` and `stabilized_publication_68e1445/` for this rerun's
publication results.** The frozen `code_68e1445/` snapshot also contains historical
repository assets, including `Figures/*` PNG/PDF files and
`Tables/All_12_Simulation_Tables.txt`. Their presence preserves source history;
it does not make them outputs of the September 17 rerun. Do not substitute those
embedded historical assets for the explicit publication directories above.

The archive includes all 64,000 raw sample/specification records. Main records
contain seven method results and retained bootstrap draws; stabilized records
contain three paired M-specific attempts, including any estimator rejections.
The frozen two population files are distributed separately below. Case-study
data and analyses are separate repository artifacts and are not inputs to this
simulation archive.

## 3. Restore the unchanged exact simulation populations when needed

Restoring summaries, independently auditing saved raw results, or rerendering
tables/figures does not require sampling new data. A fresh estimator execution
requires the exact two original population assets from the unchanged
[September 9 release](https://github.com/ykzeng-yale/SW_DSM/releases/tag/final-simulations-20260909).
Do not regenerate populations or use substitute datasets.

```sh
mkdir "$wdsm_restored/populations"
gh release download final-simulations-20260909 \
  --repo ykzeng-yale/SW_DSM \
  --pattern SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData \
  --pattern SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData \
  --dir "$wdsm_restored/populations"

cat > "$wdsm_restored/populations/POPULATION_SHA256SUMS.txt" <<'EOF'
f31b8094adccd6328f147308c8ef4de6df8f95ae19d49d3067ad2e0fabe17133  SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData
05651582c7e84792182b9cc44c6e02e12fff292b02e2bd0234794ffaf1964b4e  SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData
EOF
(cd "$wdsm_restored/populations" && shasum -a 256 -c POPULATION_SHA256SUMS.txt)
```

The good-overlap file is 84,969,654 bytes and the poor-overlap file is 84,978,749
bytes. Their GitHub release asset SHA-256 digests were rechecked while preparing
these instructions. They are the original fixed simulated populations, not
case-study participant data.

## 4. Independently repeat both strict raw-record summaries

Production used R 4.4.2 on Bouchet. Full R/package identities are retained in the
raw manifests. Use that environment when reproducing exact arithmetic; another
R/platform may produce minor floating-point or serialization differences and
must be checked numerically rather than declared byte-identical.

Run the following on a machine with adequate memory, or as scheduled Bouchet
compute work. The full strict main audit reads every retained bootstrap draw;
it is not a lightweight login-node operation. All outputs below go to new
directories and preserve the restored originals.

```sh
Rscript --vanilla "$wdsm_repo/Tables/summarize_wdsm_final.R" \
  --input "$wdsm_restored/production_68e1445" \
  --output "$wdsm_recheck/main-summary" --strict true

Rscript --vanilla "$wdsm_repo/StabilizedWDSM/Tables/summarize_stabilized.R" \
  --input "$wdsm_restored/stabilized_production_68e1445" \
  --baseline-root "$wdsm_restored/production_68e1445" \
  --output "$wdsm_recheck/stabilized-summary" --strict true
```

Require successful exit status and complete summary manifests. The main result
must have 224 cell/method metric rows; stabilized must have 96 cell/M rows and
complete original-run pairing. Missing records, unreviewed warnings or integrity
errors prevent finalization. Do not use `--strict false` to publish an incomplete
run. Expected nonpositive/rank-deficient rho rejections are retained as estimator
outcomes; they are not silently dropped. Where any requested stabilized estimate
fails, its full-run primary stabilized performance remains unavailable.

The summaries validate source/data hashes as lineage identifiers and check saved
configurations and results. They do not claim to have reread unavailable original
absolute paths embedded in the historical manifests. Do not edit those manifests
to replace Bouchet paths with local paths.

## 5. Rerender the complete tables and figures from the rechecked summaries

Use the tagged repository's current renderers. Plotting requires `ggplot2`,
`dplyr`, `gridExtra`, `grid` and `cowplot`, with package versions recorded in the
original manifests. Figure rendering can differ between graphics-library
versions; numerical inputs and displayed values must agree independently.

```sh
Rscript --vanilla "$wdsm_repo/Tables/generate_wdsm_final_tables.R" \
  --summary "$wdsm_recheck/main-summary" \
  --output "$wdsm_recheck/main-publication/Tables"

Rscript --vanilla "$wdsm_repo/Figures/generate_wdsm_final_figures.R" \
  --summary "$wdsm_recheck/main-summary" \
  --output "$wdsm_recheck/main-publication/Figures" --layout all

Rscript --vanilla "$wdsm_repo/StabilizedWDSM/Tables/generate_performance_outputs.R" \
  --summary "$wdsm_recheck/stabilized-summary" \
  --output "$wdsm_recheck/stabilized-publication"

python3 "$wdsm_repo/audit/ties_20260917/verify_publication_artifacts.py" \
  --repo "$wdsm_repo" \
  --main-summary "$wdsm_recheck/main-summary" \
  --main-publication "$wdsm_recheck/main-publication" \
  --stabilized-summary "$wdsm_recheck/stabilized-summary" \
  --stabilized-publication "$wdsm_recheck/stabilized-publication" \
  --output "$wdsm_recheck/publication_verification.json"
```

The publication validator checks the exact grid, source hashes, summary and
renderer provenance, displayed table values, comparison CSV, every expected
figure path and independent metrics from the complete records CSVs. It matches
all 96,000 original point estimates in the stabilized records to the main
records. Do not add `--skip-records` for this full restoration. To verify the
**archived** rendering itself, run it separately with the restored
`final_verified_68e1445`, `publication_68e1445`,
`stabilized_final_verified_68e1445`, and `stabilized_publication_68e1445` folders;
use a different report filename.

Each of the four main table fragments includes PATE/PATT, all four model
specifications, four comparators and WDSM M=1/3/5. Filenames use these prefixes:
`Retrospective_GoodOverlap`, `Retrospective_PoorOverlap`,
`Prospective_GoodOverlap`, and `Prospective_PoorOverlap`.
`All_4_Final_Simulation_Tables.tex` concatenates the four main tables. Main tables
report **signed relative bias**; main figures report **absolute relative bias**.

The main figure tree has 72 files:

| M | Path below `main-publication/Figures/` |
|---|---|
| 1 | `M1/{Retrospective,Prospective}/{vertical,horizontal}/{png,pdf}/{lines,dots_solid,dots_hollow}.{png,pdf}` |
| 3 | `M3/{Retrospective,Prospective}/{vertical,horizontal}/{png,pdf}/{lines,dots_solid,dots_hollow}.{png,pdf}` |
| 5 | `{Retrospective,Prospective}/{vertical,horizontal}/{png,pdf}/{lines,dots_solid,dots_hollow}.{png,pdf}` |

**There is no M5 directory: the root design folders represent M=5.** Each
design/M figure retains both overlap levels, both estimands and all four model
specifications. The same relative mapping applies to the archived
`publication_68e1445/Figures/` and finalized repository result tree.

Stabilized outputs are the four `_comparison.tex` tables,
`All_4_Stabilized_Comparison_Tables.tex`, `primary_point_comparison.csv`,
`point_comparison_tables.md`, and six figures: PNG/PDF versions of
`Retrospective_signed_relative_bias`, `Prospective_signed_relative_bias` and
`absolute_relative_bias_reduction`. Primary means remain unavailable in failed
settings. Conditional-on-success summaries are explicitly separate and must
not replace those missing primary means. Any Monte Carlo error interval in
these performance tables describes simulation precision for a bias comparison;
it is **not** a confidence interval for a stabilized causal effect.

## 6. Compile the eight-table review PDF

The R renderers generate TeX fragments. With `pdflatex` and Poppler (`pdfinfo`,
`pdftotext`, `pdftoppm`) available, compile all eight tables from the passed
full-record publication report:

```sh
python3 "$wdsm_repo/audit/ties_20260917/compile_publication_tables.py" \
  --verification-report "$wdsm_recheck/publication_verification.json" \
  --main-tables "$wdsm_recheck/main-publication/Tables" \
  --stabilized-performance "$wdsm_recheck/stabilized-publication" \
  --output "$wdsm_recheck/compiled-tables" \
  --label 'September 17, 2026 tie-corrected simulations'
```

The result is `Combined_Simulation_Tables.pdf` with eight native landscape pages, exact copied
table fragments, compiler logs, a manifest, extracted text and eight page
previews. The compiler rejects changed inputs, failed compilation, overfull
boxes, wrong page counts, text outside the page bounds and incomplete page rendering. Review all eight table
pages and all 39 distinct PNG figures for readability, clipping, legends and
failure annotations. Neither compilation nor numerical checks automatically
constitute visual review.

## A fresh estimator run is separate from restoration

For another estimator execution, use the frozen `code_68e1445/` estimator and
driver files with the two exact populations and the configuration/seed rules
in the manifests and committed September 17 protocol. Inspect both drivers'
`--help` interfaces before preparing scheduled compute jobs. Preserve the
same sampled records, seeds, M values, model specifications and B=200 when
making a paired comparison. Use new output directories; do not run estimators
over the restored completed records or modify the September 9 baseline.

Numerical reproducibility does not itself establish the asymptotic assumptions
or variance consistency proofs. The earlier correction of bootstrap/score
handling and the subsequent boundary-tie correction are separate changes;
agreement with the corrected September 9 baseline does not validate the
original historical paper numbers.
