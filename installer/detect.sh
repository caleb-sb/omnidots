# shellcheck shell=bash
#
# Hardware capability detection. Source this file after lib.sh, then call
# detect_capabilities to set and export the HAS_* flags.
#
# Inputs, overridable so tests can feed in recorded machines:
#   OMNIDOTS_LSPCI_FILE  recorded `lspci -n` output (default: run `lspci -n`)
#   OMNIDOTS_SYSFS_ROOT  sysfs root (default: /sys)
#
# A HAS_* variable already set in the environment (to 0 or 1) overrides
# detection.

# Each GPU flag and the PCI vendor ID that sets it.
declare -A GPU_VENDOR_IDS=(
  [HAS_NVIDIA]=10de
  [HAS_AMD_GPU]=1002
  [HAS_INTEL_GPU]=8086
)

# Display order for the confirmation prompt and the plan.
# shellcheck disable=SC2034 # read by install.sh
CAPABILITY_FLAGS=(HAS_NVIDIA HAS_AMD_GPU HAS_INTEL_GPU)

# pci_devices — `lspci -n` style lines: "<slot> <class>: <vendor>:<device>".
# Falls back to sysfs when lspci isn't installed (Minimal lacks pciutils).
pci_devices() {
  if [[ -n ${OMNIDOTS_LSPCI_FILE:-} ]]; then
    cat -- "$OMNIDOTS_LSPCI_FILE"
  elif command -v lspci >/dev/null; then
    lspci -n
  else
    local dev class vendor device
    for dev in "${OMNIDOTS_SYSFS_ROOT:-/sys}"/bus/pci/devices/*; do
      [[ -f $dev/class ]] || continue
      read -r class <"$dev/class"
      read -r vendor <"$dev/vendor"
      read -r device <"$dev/device"
      printf '%s %s: %s:%s\n' "${dev##*/}" "${class:2:4}" "${vendor#0x}" "${device#0x}"
    done
  fi
}

# gpu_vendors — vendor IDs of PCI display-class (03xx) devices, one per line.
gpu_vendors() {
  pci_devices | awk '$2 ~ /^03/ { split($3, id, ":"); print id[1] }'
}

# set_flag <HAS_*> <0|1> — export the detected value unless overridden.
set_flag() {
  local name="$1" detected="$2"
  case "${!name:-}" in
    "") printf -v "$name" '%s' "$detected" ;;
    0 | 1) ;;
    *) die "$name must be 0 or 1, got '${!name}'" ;;
  esac
  export "${name?}"
}

detect_capabilities() {
  local vendors flag
  vendors="$(gpu_vendors)"
  for flag in "${!GPU_VENDOR_IDS[@]}"; do
    if grep -qx "${GPU_VENDOR_IDS[$flag]}" <<<"$vendors"; then
      set_flag "$flag" 1
    else
      set_flag "$flag" 0
    fi
  done
}
