#!/bin/bash
# ==============================================================================
# Step 5: Center-of-Mass Cropping
# ==============================================================================
# Crop to fixed dimensions centered on the volume center.
#
# Usage: bash 05_crop.sh <input> <output> [size_x size_y size_z]
#   <input>   ACPC-aligned image
#   <output>  Cropped image
#   Default crop: 160x214x176
# ==============================================================================

set -euo pipefail

INPUT="$1"
OUTPUT="$2"
SIZE_X="${3:-160}"
SIZE_Y="${4:-214}"
SIZE_Z="${5:-176}"

if [[ ! -f "${INPUT}" ]]; then
    echo "ERROR: Input file not found: ${INPUT}"
    exit 1
fi

echo "  [Step 5] Cropping to ${SIZE_X}x${SIZE_Y}x${SIZE_Z}: $(basename ${INPUT})"

# Get volume dimensions
cx1=$(fslinfo "${INPUT}" | grep "^dim1" | awk '{print $2}')
cy1=$(fslinfo "${INPUT}" | grep "^dim2" | awk '{print $2}')
cz1=$(fslinfo "${INPUT}" | grep "^dim3" | awk '{print $2}')

# Compute center of volume
cx=$(echo "${cx1}/2" | bc)
cy=$(echo "${cy1}/2" | bc)
cz=$(echo "${cz1}/2" | bc)

# Compute half-widths
half_x=$(echo "${SIZE_X}/2" | bc)
half_y=$(echo "${SIZE_Y}/2" | bc)
half_z=$(echo "${SIZE_Z}/2" | bc)

# Compute crop start positions
sx=$(echo "${cx}-${half_x}" | bc)
sy=$(echo "${cy}-${half_y}" | bc)
sz=$(echo "${cz}-${half_z}" | bc)

# Clamp start positions to 0 if negative
sx=$(( sx < 0 ? 0 : sx ))
sy=$(( sy < 0 ? 0 : sy ))
sz=$(( sz < 0 ? 0 : sz ))

echo "    Volume dims: ${cx1}x${cy1}x${cz1}, center: ${cx},${cy},${cz}"
echo "    Crop start: ${sx},${sy},${sz}, size: ${SIZE_X}x${SIZE_Y}x${SIZE_Z}"

fslroi "${INPUT}" "${OUTPUT}" ${sx} ${SIZE_X} ${sy} ${SIZE_Y} ${sz} ${SIZE_Z}

echo "  [Step 5] Done: $(basename ${OUTPUT})"
