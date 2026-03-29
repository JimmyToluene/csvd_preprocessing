#!/bin/bash
# ==============================================================================
# Step 3: ACPC Alignment
# ==============================================================================
# Align to anterior-posterior commissure line using a reference image.
# Uses HCP Pipelines ACPCAlignment.sh.
#
# Usage: bash 03_acpc_alignment.sh <input> <output> <omat> <ref> <acpc_script> [brainsize]
#   <input>        Bias-corrected T1w image
#   <output>       ACPC-aligned image (without .nii.gz extension)
#   <omat>         Output transformation matrix
#   <ref>          Reference image for alignment
#   <acpc_script>  Path to HCP ACPCAlignment.sh
#   [brainsize]    Brain size in mm (default: 200)
# ==============================================================================

set -euo pipefail

INPUT="$1"
OUTPUT="$2"
OMAT="$3"
REF="$4"
ACPC_SCRIPT="$5"
BRAINSIZE="${6:-200}"

if [[ ! -f "${INPUT}" ]]; then
    echo "ERROR: Input file not found: ${INPUT}"
    exit 1
fi

if [[ ! -f "${REF}" ]]; then
    echo "ERROR: Reference image not found: ${REF}"
    exit 1
fi

if [[ ! -f "${ACPC_SCRIPT}" ]]; then
    echo "ERROR: ACPCAlignment.sh not found: ${ACPC_SCRIPT}"
    exit 1
fi

WORKDIR=$(dirname "${OUTPUT}")

echo "  [Step 3] ACPC alignment: $(basename ${INPUT})"

bash "${ACPC_SCRIPT}" \
    --workingdir="${WORKDIR}" \
    --in="${INPUT}" \
    --ref="${REF}" \
    --out="${OUTPUT}" \
    --omat="${OMAT}" \
    --brainsize="${BRAINSIZE}"

echo "  [Step 3] Done: $(basename ${OUTPUT}).nii.gz"
