#!/bin/bash
# ==============================================================================
# Step 3: Skull Stripping (Brain Extraction)
# ==============================================================================
# Remove non-brain tissue using FreeSurfer SynthStrip.
#
# Usage: bash 03_skull_strip.sh <input> <output> <mask_output>
#   <input>        Bias-corrected image
#   <output>       Skull-stripped brain image
#   <mask_output>  Binary brain mask
# ==============================================================================

set -euo pipefail

INPUT="$1"
OUTPUT="$2"
MASK_OUT="$3"

if [[ ! -f "${INPUT}" ]]; then
    echo "ERROR: Input file not found: ${INPUT}"
    exit 1
fi

echo "  [Step 3] Skull stripping (SynthStrip): $(basename ${INPUT})"

if command -v mri_synthstrip &>/dev/null; then
    mri_synthstrip \
        -i "${INPUT}" \
        -o "${OUTPUT}" \
        -m "${MASK_OUT}"
else
    echo "ERROR: mri_synthstrip not found. Install FreeSurfer >= 7.3 or the standalone SynthStrip container."
    exit 1
fi

echo "  [Step 3] Done: $(basename ${OUTPUT})"
echo "    Brain mask: $(basename ${MASK_OUT})"
