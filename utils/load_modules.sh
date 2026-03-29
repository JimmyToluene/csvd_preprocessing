#!/bin/bash
# ==============================================================================
# Auto-load Required Modules
# ==============================================================================
# Source this file to check and load missing dependencies.
# Works on BU SCC (module system). On systems without modules, skips loading
# and relies on tools already being in PATH.
#
# Note: strict mode (set -euo pipefail) is temporarily disabled during module
# loading because module init scripts often contain commands that return
# non-zero exit codes, which would kill the pipeline under set -e.
#
# Usage: source utils/load_modules.sh
# ==============================================================================

# Suspend strict mode — module load sources env scripts that can fail under -e
set +eu

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

_LOADED=0
_ALREADY=0
_FAILED=0

_check_cmd() {
    local mod="$1"
    if [[ "${mod}" == "ants" ]]; then
        command -v AntsN4BiasFieldCorrectionFs &>/dev/null || command -v N4BiasFieldCorrection &>/dev/null
    else
        local cmd="$2"
        command -v "${cmd}" &>/dev/null
    fi
}

for entry in "${REQUIRED_MODULES[@]}"; do
    mod="${entry%%:*}"
    cmd="${entry##*:}"

    if _check_cmd "${mod}" "${cmd}"; then
        _ALREADY=$((_ALREADY + 1))
        continue
    fi

    # Command not found — try loading the module
    if [[ "${HAS_MODULE_SYSTEM}" == "true" ]]; then
        echo "  Loading module: ${mod}..."
        module load "${mod}" 2>/dev/null

        if _check_cmd "${mod}" "${cmd}"; then
            _LOADED=$((_LOADED + 1))
        else
            echo "  ERROR: Failed to load module '${mod}' (command '${cmd}' still not found)"
            _FAILED=$((_FAILED + 1))
        fi
    else
        echo "  ERROR: '${cmd}' not found and no module system available"
        _FAILED=$((_FAILED + 1))
    fi
done

# Summary
if [[ ${_LOADED} -gt 0 || ${_FAILED} -gt 0 ]]; then
    echo "  Modules: ${_ALREADY} already loaded, ${_LOADED} auto-loaded, ${_FAILED} failed"
fi

# Restore strict mode before returning to the pipeline
set -euo pipefail

if [[ ${_FAILED} -gt 0 ]]; then
    echo "  ERROR: ${_FAILED} required module(s) could not be loaded. Aborting."
    exit 1
fi
