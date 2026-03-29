#!/bin/bash
# ==============================================================================
# Step 2: N4 Bias Field Correction
# ==============================================================================
# Remove intensity inhomogeneity from RF coil using ANTs N4.
#
# Usage: bash 02_n4_bias_correction.sh <input> <output>
#   <input>   Reoriented T1w image
#   <output>  Bias-corrected image
# ==============================================================================

set -euo pipefail

INPUT="$1"
OUTPUT="$2"

if [[ ! -f "${INPUT}" ]]; then
    echo "ERROR: Input file not found: ${INPUT}"
    exit 1
fi

echo "  [Step 2] N4 bias field correction: $(basename ${INPUT})"

# Try AntsN4BiasFieldCorrectionFs first, fall back to N4BiasFieldCorrection
if command -v AntsN4BiasFieldCorrectionFs &>/dev/null; then
    AntsN4BiasFieldCorrectionFs \
        -i "${INPUT}" \
        -o "${OUTPUT}"
elif command -v N4BiasFieldCorrection &>/dev/null; then
    N4BiasFieldCorrection \
        -d 3 \
        -i "${INPUT}" \
        -o "${OUTPUT}"
else
    echo "ERROR: Neither AntsN4BiasFieldCorrectionFs nor N4BiasFieldCorrection found."
    exit 1
fi

echo "  [Step 2] Done: $(basename ${OUTPUT})"
