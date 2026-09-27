#!/usr/bin/env bash
#
# Fingerprint authentication, when the machine has a reader: fprintd, and
# authselect's with-fingerprint feature, which adds pam_fprintd to system-auth
# so sudo and polkit accept a finger or the password. hyprlock talks to fprintd
# itself (see config/hypr/hyprlock.conf). Then it offers to enroll a finger.
# That's interactive, so this module runs near the end; only the NVIDIA
# post-steps come later, to keep their MOK instructions last on screen.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

has_flag HAS_FPRINT || exit 0

log_info "Setting up fingerprint authentication"

install_package_list fprint

# Only when it isn't already on, so a re-run changes nothing.
if is_dry_run || [[ " $(authselect current --raw 2>/dev/null) " != *" with-fingerprint "* ]]; then
  run sudo authselect enable-feature with-fingerprint
fi

if is_dry_run; then
  plan ask fprintd-enroll
  exit 0
fi

# fprintd is D-Bus activated, so the reader shows up without enabling a
# service. HAS_FPRINT only matched the USB vendor; this asks libfprint.
if ! listing="$(fprintd-list "$(id -un)" 2>&1)" || [[ $listing == *"No devices"* ]]; then
  log_warn "fprintd doesn't see a fingerprint reader, so fingerprint login won't work yet."
  log_warn "libfprint may not support this reader: https://fprint.freedesktop.org/supported-devices.html"
  exit 0
fi

read -r -p "Enroll a fingerprint now? [y/N] " answer || answer=
if [[ $answer == [yY]* ]]; then
  fprintd-enroll || log_warn "Enrollment failed. Run fprintd-enroll to try again."
else
  log_info "Skipped. Run fprintd-enroll to enroll a finger later."
fi
