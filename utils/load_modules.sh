#!/bin/bash
# ==============================================================================
# Auto-load Required Modules
# ==============================================================================
# Source this file to check and load missing dependencies.
# Works on BU SCC (module system). On systems without modules, skips loading
# and relies on tools already being in PATH.
#
# Usage: source utils/load_modules.sh
# ==============================================================================

# Module-to-command mapping: each entry is "module_name:test_command"
REQUIRED_MODULES=(
    "fsl:flirt"
    "afni:3dresample"
    "ants:N4BiasFieldCorrection"
    "freesurfer:mri_synthstrip"
)

# Check if the module system is available
HAS_MODULE_SYSTEM=false
if type module &>/dev/null; then
    HAS_MODULE_SYSTEM=true
fi

LOADED=0
ALREADY=0
FAILED=0

for entry in "${REQUIRED_MODULES[@]}"; do
    mod="${entry%%:*}"
    cmd="${entry##*:}"

    # ANTs has two possible commands
    if [[ "${mod}" == "ants" ]]; then
        if command -v AntsN4BiasFieldCorrectionFs &>/dev/null || command -v N4BiasFieldCorrection &>/dev/null; then
            ALREADY=$((ALREADY + 1))
            continue
        fi
    else
        if command -v "${cmd}" &>/dev/null; then
            ALREADY=$((ALREADY + 1))
            continue
        fi
    fi

    # Command not found — try loading the module
    if [[ "${HAS_MODULE_SYSTEM}" == "true" ]]; then
        echo "  Loading module: ${mod}..."
        if module load "${mod}" 2>/dev/null; then
            # Verify the command is now available
            if [[ "${mod}" == "ants" ]]; then
                if command -v AntsN4BiasFieldCorrectionFs &>/dev/null || command -v N4BiasFieldCorrection &>/dev/null; then
                    LOADED=$((LOADED + 1))
                    continue
                fi
            else
                if command -v "${cmd}" &>/dev/null; then
                    LOADED=$((LOADED + 1))
                    continue
                fi
            fi
        fi
        echo "  ERROR: Failed to load module '${mod}' (command '${cmd}' still not found)"
        FAILED=$((FAILED + 1))
    else
        echo "  ERROR: '${cmd}' not found and no module system available"
        FAILED=$((FAILED + 1))
    fi
done

# Summary
if [[ ${LOADED} -gt 0 || ${FAILED} -gt 0 ]]; then
    echo "  Modules: ${ALREADY} already loaded, ${LOADED} auto-loaded, ${FAILED} failed"
fi

if [[ ${FAILED} -gt 0 ]]; then
    echo "  ERROR: ${FAILED} required module(s) could not be loaded. Aborting."
    exit 1
fi
