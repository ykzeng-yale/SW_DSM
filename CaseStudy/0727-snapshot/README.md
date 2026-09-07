# Full 0727 source-folder snapshot — 2026-09-07

This preserves the original `0727 Test (SW_DSM)` folder before a new case-study rerun. The original code and numerical results have not been changed or rerun by this upload.

- [Browse code and smaller files](../0727%20Test%20%28SW_DSM%29/)
- [Download the complete folder archive](https://github.com/ykzeng-yale/SW_DSM/releases/tag/0727-full-snapshot-20260907)
- [Full inventory and SHA-256 checksums](SOURCE_MANIFEST.json)

The snapshot contains **7,106 regular files, 114 symbolic links, and 516 subdirectories** (15,374,215,446 bytes in regular files). The browsable copy contains 6,872 files at most 10 MB each, excluding nested Git metadata. The complete archive contains **all** source files, larger data and result objects, nested Git metadata, symbolic links, and empty directories. Files omitted from the browsable copy are explicitly marked in the manifest. No source file is omitted from the archive.

GitHub rejects ordinary Git files above 100 MiB. The full archive is therefore attached to this repository's release in ordered parts below 1.8 GB each. Identical file contents are archived once using tar hard links; extraction restores every original filename with the same bytes. This snapshot does not preserve macOS extended attributes. Symbolic-link targets are preserved exactly, including any original absolute paths.

## Restore the full folder

Install the GitHub CLI and authenticate to the private repository. In an empty download directory:

```sh
gh release download 0727-full-snapshot-20260907 --repo ykzeng-yale/SW_DSM --pattern '0727-SW_DSM-full.tar.gz.part*' --pattern SHA256SUMS
shasum -a 256 -c SHA256SUMS
mkdir restored
cat 0727-SW_DSM-full.tar.gz.part* | tar -xzf - -C restored
```

Verify every regular file and symbolic link against the inventory:

```sh
python3 verify_snapshot.py 'restored/0727 Test (SW_DSM)'
```

`verify_snapshot.py` and `SOURCE_MANIFEST.json` are in this directory. Restoration should use an empty directory. Some source symbolic links may need their original target folders when running code on a different machine; the manifest records their exact original targets.

## Context for the later rerun

The related task, **WDSM Derivation Check and Jiaqi Comments**, identified differences between hard-coded figure values and the repository README, a possible ATE-bootstrap match-list issue in the saved package version, and omitted survey weights in the older NHANES SW-PSM comparison. This snapshot preserves the evidence; it does not certify or fix those findings.

For exact reproduction, retain the original estimator code, seeds, package versions, input data, and interval construction, and write new outputs to a separate location. Any subsequent corrected analysis should be distinguishable from reproduction of the original code.
