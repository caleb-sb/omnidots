# shellcheck shell=bash
#
# Hardware capability detection. Source this file after lib.sh, then call
# detect_capabilities to set and export the HAS_* flags.
#
# Inputs, overridable so tests can feed in recorded machines:
#   OMNIDOTS_LSPCI_FILE  recorded `lspci -n` output (default: run `lspci -n`)
#   OMNIDOTS_SYSFS_ROOT  sysfs root (default: /sys), read for the battery,
#                        backlight, Bluetooth, USB devices and Secure Boot
#                        state
#
# A HAS_* variable already set in the environment (to 0 or 1) overrides
# detection.

# Each GPU flag and the PCI vendor ID that sets it.
declare -A GPU_VENDOR_IDS=(
  [HAS_NVIDIA]=10de
  [HAS_AMD_GPU]=1002
  [HAS_INTEL_GPU]=8086
)

# USB vendor IDs of the fingerprint reader makers libfprint supports. The
# vendor alone decides: Synaptics and Elan also make touchpads and
# touchscreens, but laptop touchpads sit on I2C or PS/2, not USB. A USB Elan
# touchscreen would still count; HAS_FPRINT=0 overrides that.
FPRINT_USB_VENDOR_IDS=(
  27c6 # Goodix
  06cb # Synaptics
  04f3 # Elan
  138a # Validity
  1c7a # Egis (LighTuning)
  2808 # FocalTech
)

# Display order for the confirmation prompt and the plan.
# shellcheck disable=SC2034 # read by install.sh
CAPABILITY_FLAGS=(HAS_NVIDIA HAS_AMD_GPU HAS_INTEL_GPU HAS_LEGACY_INTEL_GPU
  HAS_HYBRID_GPU HAS_BATTERY HAS_BACKLIGHT HAS_BLUETOOTH HAS_FPRINT)

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

# gpu_devices — PCI display-class (03xx) devices, one per line, as
# "<domain:bus:dev.fn> <vendor> <device> <class>". lspci -n omits the domain;
# it's 0000.
gpu_devices() {
  pci_devices | awk '$2 ~ /^03/ {
    slot = $1
    if (split(slot, parts, ":") == 2) slot = "0000:" slot
    split($3, id, ":")
    print slot, id[1], id[2], substr($2, 1, 4)
  }'
}

# is_legacy_intel_gpu <device-id> — true for Intel GPUs that intel-media-driver
# doesn't support: everything before Broadwell, plus Braswell/Cherry View
# (see https://github.com/intel/media-driver#supported-platforms). Those use
# libva-intel-driver instead. The set is closed, so it's listed here and any
# other Intel GPU counts as modern. Ranges checked against the PCI ID database
# (pci.ids).
is_legacy_intel_gpu() {
  case "$1" in
    # i8xx, GMA 900/950/3000/X3100/4500, Pineview
    1132 | 1240 | 1a12 | 25?? | 27?? | 29?? | 2a?? | 2e?? | 3577 | 358? | 712[135] | a0[01]?) ;;
    # Ironlake, Sandy Bridge, Ivy Bridge
    004[26a] | 01??) ;;
    # Haswell; 0a84 is Broxton (Gen9), so only 0a0x-0a2x
    04?? | 0a[012]? | 0c?? | 0d??) ;;
    # Bay Trail, older Atoms, Braswell/Cherry View
    0f3? | 080d | 08cf | 0be? | 22b?) ;;
    *) return 1 ;;
  esac
}

# gpus_integrated_first — the slots from gpu_devices, integrated GPUs first:
# Intel, then AMD, then everything else, each in bus order.
gpus_integrated_first() {
  gpu_devices | awk '{ print ($2 == "8086" ? 0 : $2 == "1002" ? 1 : 2), $1 }' |
    sort -s -n -k1,1 | cut -d' ' -f2
}

# secure_boot_enabled — true when UEFI Secure Boot is on. The SecureBoot EFI
# variable is 4 attribute bytes followed by one data byte, 1 when enabled.
secure_boot_enabled() {
  local var="${OMNIDOTS_SYSFS_ROOT:-/sys}/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-e39d0f1c1e1f"
  [[ -r $var ]] && [[ $(od -An -tu1 -j4 -N1 "$var" | tr -d ' ') == 1 ]]
}

# has_class_device <class> — true when sysfs lists a device of that class,
# e.g. backlight or bluetooth.
has_class_device() {
  local dev
  for dev in "${OMNIDOTS_SYSFS_ROOT:-/sys}/class/$1"/*; do
    [[ -e $dev ]] && return 0
  done
  return 1
}

# has_system_battery — true when a power supply is a battery that powers the
# machine. AC adapters and USB-C ports have type Mains or USB. Wireless mice,
# keyboards and headsets report type Battery too, but with scope Device.
has_system_battery() {
  local supply type scope
  for supply in "${OMNIDOTS_SYSFS_ROOT:-/sys}"/class/power_supply/*; do
    [[ -r $supply/type ]] || continue
    read -r type <"$supply/type"
    scope=System
    [[ -r $supply/scope ]] && read -r scope <"$supply/scope"
    [[ $type == Battery && $scope != Device ]] && return 0
  done
  return 1
}

# has_fprint_reader — true when a USB device comes from a fingerprint reader
# vendor. Interfaces (e.g. 1-3:1.0) and anything else without idVendor are
# skipped.
has_fprint_reader() {
  local id vendor known
  for id in "${OMNIDOTS_SYSFS_ROOT:-/sys}"/bus/usb/devices/*/idVendor; do
    [[ -r $id ]] || continue
    read -r vendor <"$id"
    for known in "${FPRINT_USB_VENDOR_IDS[@]}"; do
      [[ $vendor == "$known" ]] && return 0
    done
  done
  return 1
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
  local gpus vendors flag vendor device legacy=0 hybrid=0
  local battery=0 backlight=0 bluetooth=0 fprint=0
  gpus="$(gpu_devices)"
  vendors="$(cut -d' ' -f2 <<<"$gpus")"
  for flag in "${!GPU_VENDOR_IDS[@]}"; do
    if grep -qx "${GPU_VENDOR_IDS[$flag]}" <<<"$vendors"; then
      set_flag "$flag" 1
    else
      set_flag "$flag" 0
    fi
  done

  while read -r _ vendor device _; do
    if [[ $vendor == 8086 ]] && is_legacy_intel_gpu "$device"; then
      legacy=1
    fi
  done <<<"$gpus"
  set_flag HAS_LEGACY_INTEL_GPU "$legacy"

  # Hybrid: a discrete GPU with no display outputs (class 0302, 3D controller)
  # next to an Intel or AMD GPU that drives the screens. That's a muxless
  # laptop, where the dGPU should sleep when idle. A card that reports 0300
  # (VGA) has outputs of its own, as on a desktop, so it doesn't count. MUX
  # laptops whose dGPU reports 0300 need HAS_HYBRID_GPU=1.
  if awk '$4 == "0302" { dgpu = 1 }
    $4 != "0302" && ($2 == "8086" || $2 == "1002") { igpu = 1 }
    END { exit !(dgpu && igpu) }' <<<"$gpus"; then
    hybrid=1
  fi
  set_flag HAS_HYBRID_GPU "$hybrid"

  if has_system_battery; then battery=1; fi
  if has_class_device backlight; then backlight=1; fi
  if has_class_device bluetooth; then bluetooth=1; fi
  set_flag HAS_BATTERY "$battery"
  set_flag HAS_BACKLIGHT "$backlight"
  set_flag HAS_BLUETOOTH "$bluetooth"

  if has_fprint_reader; then fprint=1; fi
  set_flag HAS_FPRINT "$fprint"
}
