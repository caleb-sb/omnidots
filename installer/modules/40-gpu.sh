#!/usr/bin/env bash
#
# Drivers and video acceleration for the GPUs present. On NVIDIA machines this
# also prepares the Secure Boot signing key and, on hybrids, runtime power
# management. 99-nvidia-kmod.sh waits for the kernel module build at the end.
# Current NVIDIA drivers need no kernel command-line edits, so GRUB is left
# alone.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=installer/detect.sh
source "$(dirname "${BASH_SOURCE[0]}")/../detect.sh"

AKMODS_KEY=/etc/pki/akmods/certs/public_key.der
NVIDIA_PM_CONF=/etc/modprobe.d/nvidia-runtime-pm.conf
# Fine-grained runtime D3: the dGPU powers off when idle. Default on Ampere
# and newer laptops; this also turns it on for Turing.
NVIDIA_PM_OPTION="options nvidia NVreg_DynamicPowerManagement=0x02"

# prepare_secure_boot — akmods signs the NVIDIA module with a local key. The
# key has to exist before the first build, and be enrolled as a MOK for the
# signed module to load.
prepare_secure_boot() {
  log_warn "Secure Boot is on: the NVIDIA module will be signed with a local key that you enroll as a MOK."
  install_packages akmods mokutil
  run sudo kmodgenca -a
  if ! is_dry_run; then
    local state
    state="$(sudo mokutil --test-key "$AKMODS_KEY" 2>&1 || true)"
    if [[ $state == *already* ]]; then
      log_info "The akmods key is already enrolled or queued for enrollment."
      return
    fi
  fi
  log_info "mokutil asks for a one-time password. You'll type it again at the next boot to enroll the key."
  run sudo mokutil --import "$AKMODS_KEY"
}

write_nvidia_pm_conf() {
  printf '%s\n' "$NVIDIA_PM_OPTION" | sudo tee "$NVIDIA_PM_CONF" >/dev/null
}

log_info "Installing GPU drivers"

lists=()
if has_flag HAS_NVIDIA; then
  lists+=(nvidia)
fi
if has_flag HAS_AMD_GPU; then
  lists+=(amd-gpu)
fi
if has_flag HAS_INTEL_GPU; then
  if has_flag HAS_LEGACY_INTEL_GPU; then
    lists+=(intel-gpu-legacy)
  else
    lists+=(intel-gpu-modern)
  fi
fi

if has_flag HAS_NVIDIA && secure_boot_enabled; then
  prepare_secure_boot
fi

((${#lists[@]} == 0)) || install_package_list "${lists[@]}"

# Mesa drives AMD and Intel GPUs. Fedora's Mesa VA drivers lack H.264 and HEVC.
if has_flag HAS_AMD_GPU || has_flag HAS_INTEL_GPU; then
  act swap "mesa-va-drivers -> mesa-va-drivers-freeworld" \
    sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
fi

if has_flag HAS_HYBRID_GPU; then
  if has_flag HAS_NVIDIA; then
    act conf "$NVIDIA_PM_CONF $NVIDIA_PM_OPTION" write_nvidia_pm_conf
  fi
  # Hyprland renders on the first GPU in its device list. The Hyprland config
  # puts the integrated GPU first so the discrete one can sleep.
  order="$(gpus_integrated_first | paste -sd' ')"
  if is_dry_run; then
    plan gpu-order "$order"
  else
    log_info "Hybrid GPUs: Hyprland uses the integrated GPU first ($order)"
  fi
fi
