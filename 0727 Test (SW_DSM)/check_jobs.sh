#!/bin/bash

echo "Checking job status on McCleary..."
echo ""

ssh yz2324@login2.mccleary.ycrc.yale.edu << 'EOF'
echo "Current jobs for yz2324:"
echo "========================"
squeue -u yz2324 --format="%.18i %.9P %.20j %.8u %.8T %.10M %.9l %.6D %R"
echo ""
echo "Summary:"
squeue -u yz2324 | tail -n +2 | wc -l | xargs -I{} echo "Total jobs: {}"
echo ""
echo "Job details:"
for jobid in 57925626 57925633 57925640 57925646; do
    echo -n "Job $jobid: "
    squeue -j $jobid 2>/dev/null | tail -n +2 | awk '{print $5}' || echo "Not found/Completed"
done
EOF


