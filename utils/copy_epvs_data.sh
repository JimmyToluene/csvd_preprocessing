#!/bin/bash
# ==============================================================================
# Copy T1w and T2w from Xiao Da's EPVS_Sample_Data to our working folder
# ==============================================================================
# Usage: bash utils/copy_epvs_data.sh
# ==============================================================================

set -euo pipefail

SRC="/projectnb/bucbi/xda/EPVS_Sample_Data/Test"
DST="/projectnb/bucbi/hzj/Working_Folders/EPVS_Sample_New"

mkdir -p "${DST}"

count=0
for subj in "${SRC}"/*/; do
    id=$(basename "$subj")
    [[ "$id" == "log.txt" ]] && continue

    mkdir -p "${DST}/${id}"
    cp "${subj}/T1w.nii.gz" "${DST}/${id}/" 2>/dev/null || true
    cp "${subj}/T2w.nii.gz" "${DST}/${id}/" 2>/dev/null || true
    count=$((count + 1))
    echo "  Copied: ${id}"
done

echo ""
echo "Done. ${count} subjects copied to ${DST}"
