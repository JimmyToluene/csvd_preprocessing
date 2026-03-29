#!/bin/bash
# ==============================================================================
# Step 6: Intensity Normalization
# ==============================================================================
# Normalize intensities to [0, 1] range using one of three methods.
# If a brain mask is provided, percentiles are computed within the mask only,
# matching the SHiVAi convention for brain-masked normalization.
#
# Usage: bash 06_normalize.sh <input> <output> [method] [brain_mask]
#   <input>       Cropped T1w image
#   <output>      Normalized image
#   [method]      max_norm (default) | p1_p99 | min_max
#   [brain_mask]  Binary brain mask (optional — if given, stats computed within mask)
#
# Variants:
#   max_norm  — (I - 0) / (P99 - 0), clip [0,1]     (Xiao Da / SHIVA)
#   p1_p99   — (I - P1) / (P99 - P1), clip [0,1]    (MUJICA current)
#   min_max  — (I - min) / (max - min), clip [0,1]   (Standard ML)
# ==============================================================================

set -euo pipefail

INPUT="$1"
OUTPUT="$2"
METHOD="${3:-max_norm}"
BRAIN_MASK="${4:-}"

if [[ ! -f "${INPUT}" ]]; then
    echo "ERROR: Input file not found: ${INPUT}"
    exit 1
fi

# Build mask flag for fslstats: -k <mask> restricts stats to mask voxels
MASK_FLAG=""
if [[ -n "${BRAIN_MASK}" && -f "${BRAIN_MASK}" ]]; then
    MASK_FLAG="-k ${BRAIN_MASK}"
    echo "  [Step 6] Normalizing (${METHOD}, brain-masked): $(basename ${INPUT})"
else
    echo "  [Step 6] Normalizing (${METHOD}): $(basename ${INPUT})"
fi

TMPFILE="${OUTPUT%.nii.gz}_tmp.nii.gz"

case "${METHOD}" in
    max_norm)
        P99=$(fslstats "${INPUT}" ${MASK_FLAG} -P 99 | awk '{print $1}')
        echo "    P99=${P99}"

        3dcalc -a "${INPUT}" \
            -expr "(a)/(${P99})" \
            -prefix "${TMPFILE}" -nscale -float -overwrite

        3dcalc -a "${TMPFILE}" \
            -expr "a*within(a,0,1)" \
            -prefix "${OUTPUT}" -nscale -float -overwrite

        rm -f "${TMPFILE}"
        ;;

    p1_p99)
        P1=$(fslstats "${INPUT}" ${MASK_FLAG} -P 1 | awk '{print $1}')
        P99=$(fslstats "${INPUT}" ${MASK_FLAG} -P 99 | awk '{print $1}')
        echo "    P1=${P1}, P99=${P99}"

        3dcalc -a "${INPUT}" \
            -expr "(a-${P1})/(${P99}-${P1})" \
            -prefix "${TMPFILE}" -nscale -float -overwrite

        3dcalc -a "${TMPFILE}" \
            -expr "a*within(a,0,1)" \
            -prefix "${OUTPUT}" -nscale -float -overwrite

        rm -f "${TMPFILE}"
        ;;

    min_max)
        RANGE=$(fslstats "${INPUT}" ${MASK_FLAG} -R)
        VMIN=$(echo "${RANGE}" | awk '{print $1}')
        VMAX=$(echo "${RANGE}" | awk '{print $2}')
        echo "    min=${VMIN}, max=${VMAX}"

        3dcalc -a "${INPUT}" \
            -expr "(a-${VMIN})/(${VMAX}-${VMIN})" \
            -prefix "${TMPFILE}" -nscale -float -overwrite

        3dcalc -a "${TMPFILE}" \
            -expr "a*within(a,0,1)" \
            -prefix "${OUTPUT}" -nscale -float -overwrite

        rm -f "${TMPFILE}"
        ;;

    *)
        echo "ERROR: Unknown normalization method: ${METHOD}"
        echo "  Options: max_norm, p1_p99, min_max"
        exit 1
        ;;
esac

echo "  [Step 6] Done: $(basename ${OUTPUT})"
