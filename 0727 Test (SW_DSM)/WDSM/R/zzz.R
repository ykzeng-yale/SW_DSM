# Package initialization
.onLoad <- function(libname, pkgname) {
  # Ensure bootstrap functions are available
  # This is loaded when the package is loaded
}

# Package attachment
.onAttach <- function(libname, pkgname) {
  packageStartupMessage("wdsmatch: Weighted Double Score Matching for Survey Data")
  packageStartupMessage("Type ?wdsmatch for help")
} 