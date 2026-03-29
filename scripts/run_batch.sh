#!/bin/bash
# ==============================================================================
# Batch Processing with SGE Job Arrays
# ==============================================================================
# Submit as: qsub scripts/run_batch.sh
#
# Before running, update:
#   1. The -t range to match the number of subjects in subjects.txt
#   2. The --config path below
# ==============================================================================

#$ -t 1-164
#$ -l h_rt=01:00:00
#$ -l mem_per_core=8G
#$ -N csvd_preprocess
#$ -o logs/$JOB_NAME.$JOB_ID.$TASK_ID.out
#$ -e logs/$JOB_NAME.$JOB_ID.$TASK_ID.err
#$ -cwd

set -euo pipefail

# --- Auto-load required modules ---
source utils/load_modules.sh

# --- Configuration ---
CONFIG="configs/preprocess_config.yaml"
SUBJECTS_LIST="subjects.txt"

# Create logs directory
mkdir -p logs

# Get subject ID for this array task
SUBJECT=$(sed -n "${SGE_TASK_ID}p" "${SUBJECTS_LIST}")

if [[ -z "${SUBJECT}" ]]; then
    echo "ERROR: No subject found at line ${SGE_TASK_ID} in ${SUBJECTS_LIST}"
    exit 1
fi

echo "=== Job ${SGE_TASK_ID}: Processing ${SUBJECT} ==="

bash scripts/run_single_subject.sh --config "${CONFIG}" --subject "${SUBJECT}"

echo "=== Job ${SGE_TASK_ID}: Finished ${SUBJECT} ==="
