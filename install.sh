#!/usr/bin/env bash
#
# Turns a Fedora Minimal install into this Hyprland desktop.
#
# Usage: ./install.sh [--dry-run]
#   --dry-run  print the plan to stdout, one action per line, and change nothing
#
# Any capability flag can be forced with an environment variable of the same
# name, e.g. HAS_NVIDIA=0 ./install.sh
#
# The optional modules are asked about up front, unless chosen with
# WITH_GAMING=0|1 (Steam, Discord, Heroic) or WITH_ANDROID=0|1 (Android
# Studio). A dry-run doesn't ask, and leaves out any module not chosen.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=installer/lib.sh
source installer/lib.sh
# shellcheck source=installer/detect.sh
source installer/detect.sh

# choose_module <WITH_*> <question> — ask whether to include an optional
# module, unless the environment already chose. Not chosen means not included.
choose_module() {
  local name="$1" answer
  if [[ -z ${!name:-} ]] && ! is_dry_run; then
    read -r -p "$2 [y/N] " answer || answer=
    if [[ $answer == [yY]* ]]; then
      printf -v "$name" 1
    fi
  fi
  set_flag "$name" 0
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      sed -n '3,13s/^# \{0,1\}//p' "${BASH_SOURCE[0]##*/}"
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

# Both questions come before anything is installed, so the rest of the run
# needs no attention.
choose_module WITH_GAMING "Include gaming (Steam, Discord, Heroic)?"
choose_module WITH_ANDROID "Include Android development (Android Studio)?"
if is_dry_run; then
  plan flag "WITH_GAMING=$WITH_GAMING"
  plan flag "WITH_ANDROID=$WITH_ANDROID"
fi

for module in installer/modules/*.sh; do
  bash "$module"
done

is_dry_run || log_info "Installation complete. Reboot to start from a clean state."
