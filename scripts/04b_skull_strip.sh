#!/bin/bash
# ==============================================================================
# Step 4b: Skull Stripping (Brain Extraction)
# ==============================================================================
# Generate a brain mask and skull-stripped image from the cropped T1w.
# Runs AFTER crop (step 04) and BEFORE normalize (step 05).
#
# Usage: bash 04b_skull_strip.sh <input> <brain_output> <mask_output> [tool]
#   <input>         Cropped T1w image
#   <brain_output>  Skull-stripped brain image
#   <mask_output>   Binary brain mask
#   [tool]          synthstrip (default) | watershed
# ==============================================================================

set -euo pipefail

INPUT="$1"
BRAIN_OUT="$2"
MASK_OUT="$3"
TOOL="${4:-synthstrip}"

if [[ ! -f "${INPUT}" ]]; then
    echo "ERROR: Input file not found: ${INPUT}"
    exit 1
fi

echo "  [Step 4b] Skull stripping (${TOOL}): $(basename ${INPUT})"

case "${TOOL}" in
    synthstrip)
        if command -v mri_synthstrip &>/dev/null; then
            mri_synthstrip \
                -i "${INPUT}" \
                -o "${BRAIN_OUT}" \
                -m "${MASK_OUT}"
        else
            echo "ERROR: mri_synthstrip not found. Install FreeSurfer >= 7.3 or use skull_strip_tool: watershed"
            exit 1
        fi
        ;;

    watershed)
        if command -v mri_watershed &>/dev/null; then
            mri_watershed "${INPUT}" "${BRAIN_OUT}"
            # Binarize to create mask
            if command -v mri_binarize &>/dev/null; then
                mri_binarize --i "${BRAIN_OUT}" --min 0.001 --o "${MASK_OUT}"
            else
                # Fallback: use fslmaths to binarize
                fslmaths "${BRAIN_OUT}" -thr 0.001 -bin "${MASK_OUT}"
            fi
        else
            echo "ERROR: mri_watershed not found. Install FreeSurfer."
            exit 1
        fi
        ;;

    *)
        echo "ERROR: Unknown skull strip tool: ${TOOL}"
        echo "  Options: synthstrip, watershed"
        exit 1
        ;;
esac

echo "  [Step 4b] Done: $(basename ${BRAIN_OUT})"
echo "    Brain mask: $(basename ${MASK_OUT})"
