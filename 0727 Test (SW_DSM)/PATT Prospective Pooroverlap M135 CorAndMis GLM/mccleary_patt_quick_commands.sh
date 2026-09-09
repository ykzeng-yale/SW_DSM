#!/bin/bash
# Quick commands for McCleary PATT comparison job (M=1,3,5 with Model Specifications - Poor Overlap)

case "$1" in
  upload)
    echo "Uploading files..."
    TIMESTAMP=$(date +%Y%m%d_%H%M)
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_M135_CorAndMis_Poor_$TIMESTAMP"
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"
    scp comprehensive_patt_comparison_mccleary.R run_patt_comparison_mccleary.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/
    scp -r WDSM dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/
    scp SuperPopGen_PoorOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/
    echo "Files uploaded to: $REMOTE_DIR"
    ;;
  submit)
    echo "Submitting job..."
    # Assumes you've already uploaded to a specific directory
    echo "Please provide the remote directory path:"
    read REMOTE_DIR
    ssh yz2324@login2.mccleary.ycrc.yale.edu "cd $REMOTE_DIR && sbatch run_patt_comparison_mccleary.sh"
    ;;
  status)
    ssh yz2324@login2.mccleary.ycrc.yale.edu "squeue -u yz2324"
    ;;
  download)
    echo "Please provide the remote directory path:"
    read REMOTE_DIR
    echo "Downloading results..."
    scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap*.RData .
    scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_M*_Pooroverlap*.csv .
    scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/comprehensive_patt_comparison_M135_CorAndMis_Pooroverlap*.pdf .
    scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/patt_M135_CorAndMis_Poor_*.out .
    scp -r yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/patt_M135_CorAndMis_Poor_*.err .
    ;;
  all)
    # Full automated submission
    ./submit_patt_comparison_mccleary.sh
    ;;
  *)
    echo "Usage: $0 {upload|submit|status|download|all}"
    echo ""
    echo "  upload   - Upload files to new timestamped directory"
    echo "  submit   - Submit job (requires directory path)"
    echo "  status   - Check job status"
    echo "  download - Download results (requires directory path)"
    echo "  all      - Run full automated submission"
    ;;
esac