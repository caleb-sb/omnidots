#!/usr/bin/env bash
#
# Turns a Fedora Minimal install into this Hyprland desktop.
#
# Usage: ./install.sh [--dry-run]
#   --dry-run  print the plan to stdout, one action per line, and change nothing
#
# Any capability flag can be forced with an environment variable of the same
# name, e.g. HAS_NVIDIA=0 ./install.sh

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=installer/lib.sh
source installer/lib.sh
# shellcheck source=installer/detect.sh
source installer/detect.sh

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      sed -n '3,9s/^# \{0,1\}//p' "${BASH_SOURCE[0]##*/}"
      exit 0
      ;;
    *) die "Unknown argument: $arg" ;;
  esac
done
export DRY_RUN

[[ $EUID -ne 0 ]] || die "Run this as your user, not root; it uses sudo where needed."

detect_capabilities

if is_dry_run; then
  for flag in "${CAPABILITY_FLAGS[@]}"; do
    plan flag "$flag=${!flag}"
  done
else
  log_info "Detected capabilities (override with e.g. HAS_NVIDIA=0 ./install.sh):"
  for flag in "${CAPABILITY_FLAGS[@]}"; do
    printf '  %s=%s\n' "$flag" "${!flag}" >&2
  done
  read -r -p "Install with these capabilities? [y/N] " answer || answer=
  [[ $answer == [yY]* ]] || die "Installation aborted."
fi

for module in installer/modules/*.sh; do
  bash "$module"
done

is_dry_run || log_info "Installation complete. Reboot to start from a clean state."
