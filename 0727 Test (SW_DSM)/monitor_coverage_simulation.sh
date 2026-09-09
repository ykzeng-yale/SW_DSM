#!/bin/bash

echo "=================================================="
echo "Monitoring WDSM Coverage Simulation"
echo "=================================================="

# Check if the process is still running
if pgrep -f "test_wdsm_coverage_simulation.R" > /dev/null; then
    echo "Status: RUNNING ✓"
    echo
    
    # Check log file
    if [ -f "wdsm_coverage_simulation_log.txt" ]; then
        echo "Recent log entries:"
        echo "------------------"
        tail -n 20 wdsm_coverage_simulation_log.txt | grep -E "(Running|Completed|simulations|Coverage|RESULTS|ERROR)"
    fi
else
    echo "Status: COMPLETED or STOPPED"
    echo
    
    # Check if results file exists
    if [ -f "wdsm_coverage_simulation_results.RData" ]; then
        echo "Results file found: wdsm_coverage_simulation_results.RData"
        echo "File size: $(ls -lh wdsm_coverage_simulation_results.RData | awk '{print $5}')"
        echo "Modified: $(ls -l wdsm_coverage_simulation_results.RData | awk '{print $6, $7, $8}')"
        echo
    fi
    
    # Show final results from log
    if [ -f "wdsm_coverage_simulation_log.txt" ]; then
        echo "Final results from log:"
        echo "----------------------"
        tail -n 50 wdsm_coverage_simulation_log.txt | grep -A 50 "SIMULATION RESULTS"
    fi
fi 