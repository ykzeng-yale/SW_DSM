#!/bin/bash
# Quick commands for McCleary R jobs - PATT Retrospective

case "$1" in
  upload)
    echo "Uploading files to McCleary..."
    REMOTE_DIR="/gpfs/gibbs/project/tong/yz2324/patt_retrospective_latest"
    ssh yz2324@login2.mccleary.ycrc.yale.edu "mkdir -p $REMOTE_DIR"
    scp compare_methods_patt_retrospective_mccleary.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/
    scp wdsm_patt_v2_standard.R yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/
    scp SuperPopGen_GoodOverlap_AllinOne_0118_2025.RData yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/
    scp -r dsmatch-master yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/
    scp submit_patt_retrospective_mccleary.sh yz2324@login2.mccleary.ycrc.yale.edu:$REMOTE_DIR/
    echo "Files uploaded to $REMOTE_DIR"
    ;;
  submit)
    echo "Submitting job..."
    ssh yz2324@login2.mccleary.ycrc.yale.edu "cd /gpfs/gibbs/project/tong/yz2324/patt_retrospective_latest && sbatch submit_patt_retrospective_mccleary.sh"
    ;;
  status)
    ssh yz2324@login2.mccleary.ycrc.yale.edu "squeue -u yz2324"
    ;;
  download)
    echo "Downloading results..."
    scp yz2324@login2.mccleary.ycrc.yale.edu:/gpfs/gibbs/project/tong/yz2324/patt_retrospective_latest/comprehensive_patt_retrospective_* .
    ;;
  log)
    # Show the last 50 lines of the most recent output file
    ssh yz2324@login2.mccleary.ycrc.yale.edu "cd /gpfs/gibbs/project/tong/yz2324/patt_retrospective_latest && tail -50 patt_retrospective_*.out"
    ;;
  parallel-log)
    # Show parallel processing log
    ssh yz2324@login2.mccleary.ycrc.yale.edu "cd /gpfs/gibbs/project/tong/yz2324/patt_retrospective_latest && tail -100 parallel_log.txt"
    ;;
  all)
    $0 upload && $0 submit && sleep 5 && $0 status
    ;;
  *)
    echo "Usage: $0 {upload|submit|status|download|log|parallel-log|all}"
    echo ""
    echo "Commands:"
    echo "  upload       - Upload all files to McCleary"
    echo "  submit       - Submit the job"
    echo "  status       - Check job status"
    echo "  download     - Download results"
    echo "  log          - View job output log"
    echo "  parallel-log - View parallel processing log"
    echo "  all          - Upload, submit, and check status"
    ;;
esac