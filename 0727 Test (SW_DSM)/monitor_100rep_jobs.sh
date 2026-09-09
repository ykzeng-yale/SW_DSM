#!/bin/bash
SERVER="yz2324@login2.mccleary.ycrc.yale.edu"
echo "Checking job status..."
ssh $SERVER "squeue -u \$USER --format='%.18i %.30j %.8u %.8T %.10M %.6D %R'"
