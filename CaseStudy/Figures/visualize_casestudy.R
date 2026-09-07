# Compatibility entry point; uses the verified aggregate results and plotting code.
# Run from the repository root. Requires Python 3 and matplotlib.
status <- system2(Sys.getenv("PYTHON", "python3"), "CaseStudy/Figures/plot_corrected_case_studies.py")
if (status != 0L) stop("Figure generation failed. Install matplotlib for the selected Python interpreter.")
