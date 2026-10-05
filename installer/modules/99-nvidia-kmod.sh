#!/usr/bin/env bash
#
# NVIDIA post-steps, last so the akmods build overlaps the other modules:
# wait for the kernel module so the first boot has a driver, then repeat the
# MOK enrollment steps when Secure Boot is on.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
# shellcheck source=installer/detect.sh
source "$(dirname "${BASH_SOURCE[0]}")/../detect.sh"

has_flag WITH_DESKTOP || exit 0

BUILD_TIMEOUT=1200 # seconds

# wait_for_kmod — akmod-nvidia builds the module in the background after
# install. `modinfo` finds it once the build for the running kernel is done.
wait_for_kmod() {
  log_info "Waiting for akmods to build the NVIDIA kernel module (usually a few minutes)"
  local deadline=$((SECONDS + BUILD_TIMEOUT))
  until modinfo -F version nvidia &>/dev/null; do
    if ((SECONDS >= deadline)); then
      log_warn "The NVIDIA module still isn't built. Check 'journalctl -b -t akmods' and run 'sudo akmods --force' before rebooting."
      log_warn "If this kernel is older than the newest installed one, reboot instead; akmods builds for it at boot."
      return
    fi
    sleep 10
  done
  log_info "NVIDIA module $(modinfo -F version nvidia) is built"
}

has_flag HAS_NVIDIA || exit 0

if is_dry_run; then
  plan wait "akmods build of the nvidia kernel module"
else
  wait_for_kmod
fi

if secure_boot_enabled; then
  log_warn "Secure Boot is on. If mokutil queued the akmods key, the blue MOK manager appears at the next boot:"
  log_warn "  choose Enroll MOK, then Continue, then Yes, enter the password you set with mokutil, then Reboot."
  log_warn "Skip it and the NVIDIA module won't load until the key is enrolled."
fi
