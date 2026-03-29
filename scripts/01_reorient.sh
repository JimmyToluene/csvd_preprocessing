#!/bin/bash
# ==============================================================================
# Step 1: Reorient to RAS
# ==============================================================================
# Reorient raw MRI to RAS (Right-Anterior-Superior) standard orientation.
#
# Usage: bash 01_reorient.sh <input> <output>
#   <input>   Raw T1w image (e.g., sub-001_T1_RAW.nii.gz)
#   <output>  Reoriented image (e.g., sub-001_T1_reorient.nii.gz)
# ==============================================================================

set -euo pipefail

INPUT="$1"
OUTPUT="$2"

if [[ ! -f "${INPUT}" ]]; then
    echo "ERROR: Input file not found: ${INPUT}"
    exit 1
fi

echo "  [Step 1] Reorienting to RAS: $(basename ${INPUT})"

3dresample \
    -orient RAS \
    -rmode Linear \
    -prefix "${OUTPUT}" \
    -input "${INPUT}" \
    -overwrite

echo "  [Step 1] Done: $(basename ${OUTPUT})"
