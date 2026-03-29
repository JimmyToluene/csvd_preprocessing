#!/bin/bash
# ==============================================================================
# Validate Preprocessing Output
# ==============================================================================
# QC checks on preprocessed data for a single subject (T1w and T2w).
#
# Usage: bash utils/validate_output.sh <subject_output_dir> <subject_id> [crop_x crop_y crop_z]
# ==============================================================================

set -euo pipefail

SUBJ_DIR="$1"
SUBJECT="$2"
EXPECTED_X="${3:-160}"
EXPECTED_Y="${4:-214}"
EXPECTED_Z="${5:-176}"

ERRORS=0
WARNINGS=0

# ------------------------------------------------------------------------------
# Helper: check normalization range for a file
# ------------------------------------------------------------------------------
check_norm() {
    local fpath="$1"
    local label="$2"

    if [[ -f "${fpath}" ]]; then
        RANGE=$(fslstats "${fpath}" -R)
        VMIN=$(echo "${RANGE}" | awk '{print $1}')
        VMAX=$(echo "${RANGE}" | awk '{print $2}')

        echo "  Range: [${VMIN}, ${VMAX}]"

        MAX_OK=$(echo "${VMAX} > 0.9 && ${VMAX} <= 1.001" | bc -l)
        MIN_OK=$(echo "${VMIN} >= -0.001 && ${VMIN} < 0.1" | bc -l)

        if [[ "${MAX_OK}" -eq 1 && "${MIN_OK}" -eq 1 ]]; then
            echo "  OK   ${label} intensity range within expected bounds"
        else
            echo "  WARN ${label} intensity range outside expected bounds"
            WARNINGS=$((WARNINGS + 1))
        fi

        MEAN=$(fslstats "${fpath}" -M)
        if echo "${MEAN}" | grep -qiE "nan|inf"; then
            echo "  FAIL ${label} NaN or Inf values detected (mean=${MEAN})"
            ERRORS=$((ERRORS + 1))
        else
            echo "  OK   ${label} no NaN/Inf (mean=${MEAN})"
        fi
    else
        echo "  SKIP ${label} norm file missing"
    fi
}

echo "======================================================================"
echo "  QC Validation: ${SUBJECT}"
echo "======================================================================"

# --- T1w file existence ---
echo ""
echo "--- T1w file existence ---"
# Final output
fpath="${SUBJ_DIR}/${SUBJECT}_T1_norm.nii.gz"
if [[ -f "${fpath}" ]]; then
    echo "  OK   ${SUBJECT}_T1_norm.nii.gz (final)"
else
    echo "  FAIL ${SUBJECT}_T1_norm.nii.gz — MISSING"
    ERRORS=$((ERRORS + 1))
fi
# Intermediate files
for suffix in reorient n4 crop; do
    fpath="${SUBJ_DIR}/intermediate/${SUBJECT}_T1_${suffix}.nii.gz"
    if [[ -f "${fpath}" ]]; then
        echo "  OK   intermediate/${SUBJECT}_T1_${suffix}.nii.gz"
    else
        echo "  FAIL intermediate/${SUBJECT}_T1_${suffix}.nii.gz — MISSING"
        ERRORS=$((ERRORS + 1))
    fi
done

# --- Brain mask existence ---
echo ""
echo "--- Brain mask ---"
BRAIN_MASK="${SUBJ_DIR}/T1w_brain_mask.nii.gz"
BRAIN_IMG="${SUBJ_DIR}/T1w_brain.nii.gz"
if [[ -f "${BRAIN_MASK}" ]]; then
    echo "  OK   T1w_brain_mask.nii.gz"
else
    echo "  FAIL T1w_brain_mask.nii.gz — MISSING"
    ERRORS=$((ERRORS + 1))
fi
if [[ -f "${BRAIN_IMG}" ]]; then
    echo "  OK   T1w_brain.nii.gz"
else
    echo "  FAIL T1w_brain.nii.gz — MISSING"
    ERRORS=$((ERRORS + 1))
fi

# --- T2w file existence (optional) ---
echo ""
echo "--- T2w file existence ---"
T2_FOUND=false
# Final output
if [[ -f "${SUBJ_DIR}/${SUBJECT}_T2_norm.nii.gz" ]]; then
    echo "  OK   ${SUBJECT}_T2_norm.nii.gz (final)"
    T2_FOUND=true
fi
# Intermediate files
for suffix in reorient n4 coreg; do
    fpath="${SUBJ_DIR}/intermediate/${SUBJECT}_T2_${suffix}.nii.gz"
    if [[ -f "${fpath}" ]]; then
        echo "  OK   intermediate/${SUBJECT}_T2_${suffix}.nii.gz"
        T2_FOUND=true
    fi
done
if [[ "${T2_FOUND}" == "false" ]]; then
    echo "  SKIP No T2w outputs found (T2 processing may be disabled)"
fi

# --- T1w crop dimensions ---
echo ""
echo "--- T1w crop dimensions (expected: ${EXPECTED_X}x${EXPECTED_Y}x${EXPECTED_Z}) ---"
CROP_FILE="${SUBJ_DIR}/intermediate/${SUBJECT}_T1_crop.nii.gz"
if [[ -f "${CROP_FILE}" ]]; then
    DIM_X=$(fslinfo "${CROP_FILE}" | grep "^dim1" | awk '{print $2}')
    DIM_Y=$(fslinfo "${CROP_FILE}" | grep "^dim2" | awk '{print $2}')
    DIM_Z=$(fslinfo "${CROP_FILE}" | grep "^dim3" | awk '{print $2}')

    if [[ "${DIM_X}" -eq "${EXPECTED_X}" && "${DIM_Y}" -eq "${EXPECTED_Y}" && "${DIM_Z}" -eq "${EXPECTED_Z}" ]]; then
        echo "  OK   Dimensions: ${DIM_X}x${DIM_Y}x${DIM_Z}"
    else
        echo "  FAIL Dimensions: ${DIM_X}x${DIM_Y}x${DIM_Z} (expected ${EXPECTED_X}x${EXPECTED_Y}x${EXPECTED_Z})"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  SKIP Crop file missing"
fi

# --- T2w coreg dimensions (should match T1w crop) ---
T2_COREG_FILE="${SUBJ_DIR}/intermediate/${SUBJECT}_T2_coreg.nii.gz"
if [[ -f "${T2_COREG_FILE}" ]]; then
    echo ""
    echo "--- T2w coreg dimensions (should match T1w crop: ${EXPECTED_X}x${EXPECTED_Y}x${EXPECTED_Z}) ---"
    DIM_X=$(fslinfo "${T2_COREG_FILE}" | grep "^dim1" | awk '{print $2}')
    DIM_Y=$(fslinfo "${T2_COREG_FILE}" | grep "^dim2" | awk '{print $2}')
    DIM_Z=$(fslinfo "${T2_COREG_FILE}" | grep "^dim3" | awk '{print $2}')

    if [[ "${DIM_X}" -eq "${EXPECTED_X}" && "${DIM_Y}" -eq "${EXPECTED_Y}" && "${DIM_Z}" -eq "${EXPECTED_Z}" ]]; then
        echo "  OK   Dimensions: ${DIM_X}x${DIM_Y}x${DIM_Z}"
    else
        echo "  FAIL Dimensions: ${DIM_X}x${DIM_Y}x${DIM_Z} (expected ${EXPECTED_X}x${EXPECTED_Y}x${EXPECTED_Z})"
        ERRORS=$((ERRORS + 1))
    fi
fi

# --- T1w normalization range ---
echo ""
echo "--- T1w normalization range (expected: ~[0, 1]) ---"
check_norm "${SUBJ_DIR}/${SUBJECT}_T1_norm.nii.gz" "T1w"

# --- T2w normalization range ---
T2_NORM_FILE="${SUBJ_DIR}/${SUBJECT}_T2_norm.nii.gz"
if [[ -f "${T2_NORM_FILE}" ]]; then
    echo ""
    echo "--- T2w normalization range (expected: ~[0, 1]) ---"
    check_norm "${T2_NORM_FILE}" "T2w"
fi

# --- Brain mask leakage check ---
echo ""
echo "--- Brain mask leakage check (no non-zero voxels outside mask) ---"
if [[ -f "${BRAIN_MASK}" ]]; then
    for NORM_FILE in "${SUBJ_DIR}/${SUBJECT}_T1_norm.nii.gz" "${SUBJ_DIR}/${SUBJECT}_T2_norm.nii.gz"; do
        if [[ -f "${NORM_FILE}" ]]; then
            LABEL=$(basename "${NORM_FILE}" .nii.gz)
            # Invert mask and check max of normalized * inverted_mask
            OUTSIDE_MAX=$(fslstats "${NORM_FILE}" -k <(fslmaths "${BRAIN_MASK}" -binv -) -R 2>/dev/null | awk '{print $2}' || echo "0")
            OUTSIDE_OK=$(echo "${OUTSIDE_MAX} < 0.001" | bc -l 2>/dev/null || echo "1")
            if [[ "${OUTSIDE_OK}" -eq 1 ]]; then
                echo "  OK   ${LABEL}: no signal outside brain mask"
            else
                echo "  WARN ${LABEL}: max outside mask = ${OUTSIDE_MAX}"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    done
else
    echo "  SKIP Brain mask not found, skipping leakage check"
fi

# --- Summary ---
echo ""
echo "======================================================================"
if [[ ${ERRORS} -gt 0 ]]; then
    echo "  RESULT: FAIL — ${ERRORS} error(s), ${WARNINGS} warning(s)"
    exit 1
elif [[ ${WARNINGS} -gt 0 ]]; then
    echo "  RESULT: PASS with ${WARNINGS} warning(s)"
    exit 0
else
    echo "  RESULT: PASS — all checks OK"
    exit 0
fi
