#!/bin/bash
# Quick monitoring script for job 57092566

echo "=== Checking Job Status ==="
echo ""
echo "1) Job Status:"
ssh yz2324@login2.mccleary.ycrc.yale.edu 'squeue -j 57092566'

echo ""
echo "2) To monitor output (if job is running):"
echo "   ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -f /gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_2212/patt_retrospective_*.out'"

echo ""
echo "3) To check parallel log:"
echo "   ssh yz2324@login2.mccleary.ycrc.yale.edu 'tail -100 /gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_2212/parallel_log.txt'"

echo ""
echo "4) To download results when complete:"
echo "   scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_2212/comprehensive_patt_retrospective_results.RData ."
echo "   scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_2212/comprehensive_patt_retrospective_table.csv ."
echo "   scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_2212/comprehensive_patt_retrospective_plot.pdf ."
echo "   scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_retrospective_20250804_2212/comprehensive_patt_retrospective_boxplot.pdf ."