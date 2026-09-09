# Final figure pipeline validation

The actual complete five-replication pilot at `audit/full_pilot_f299946_strict_summary` generated all 72 requested image files: two designs, three WDSM M values, horizontal/vertical layouts, line/solid-dot/faded-dot styles, and PNG/PDF formats. Every file was nonempty and linked to metrics SHA-256 `2b1947a996b2cefa81b1259e5ec114e3792cd4fed97966e00a1a4096d6308272`. The pilot preview title and directory explicitly prevent confusion with the 1000-replication manuscript results.

The retrospective horizontal dot figure and prospective vertical line figure were visually inspected for labels, legends, panel alignment, data completeness, and clipping. The horizontal bias label was clarified to Absolute Relative Bias, matching the computed metric. Final production images will require another inspection because new numerical ranges can change the layout. The local cowplot package emitted only a package-built-under-R-4.4.1 startup notice under R4.4.0; the cluster has its own recorded R4.4.2 package versions.

The renderer reads only the complete strict-summary CSV after its SHA-256 matches the PASS manifest. It requires all 224 rows, proper counts/B/alpha, and the exact method/cell grid. Pilot rendering requires an explicit preview flag. It never reads historical raw results, drops failed records, or reconstructs endpoint choices while plotting.
