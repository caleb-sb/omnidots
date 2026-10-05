#!/usr/bin/env bash
#
# Turns a Fedora Minimal install into this Hyprland desktop, or with
# --terminal any Fedora (WSL included) into just its terminal setup.
#
# Usage: ./install.sh [--terminal] [--dry-run]
#   --terminal  the shell, editor and dev tools only: no desktop, no hardware
#   --dry-run   print the plan to stdout, one action per line, and change nothing
#
# Any capability flag can be forced with an environment variable of the same
# name, e.g. HAS_NVIDIA=0 ./install.sh
#
# The optional modules are asked about up front, unless chosen with
# WITH_GAMING=0|1 (Steam, Discord, Heroic) or WITH_ANDROID=0|1 (Android
# Studio). A dry-run doesn't ask, and leaves out any module not chosen.
#
# The profile is recorded, so update.sh and later runs keep it; switch with
# --terminal or WITH_DESKTOP=1.

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

# record_profile — remember the profile for update.sh and later runs.
record_profile() {
  local profile=desktop
  has_flag WITH_DESKTOP || profile=terminal
  if is_dry_run; then
    plan profile "$PROFILE_FILE $profile"
  else
    mkdir -p "$(dirname "$PROFILE_FILE")"
    printf '%s\n' "$profile" >"$PROFILE_FILE"
  fi
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --terminal) WITH_DESKTOP=0 ;;
    -h | --help)
      sed -n '3,18s/^# \{0,1\}//p' "${BASH_SOURCE[0]##*/}"
      exit 0
      ;;
    *) die "Unknown argument: $arg" ;;
  esac
done
export DRY_RUN

[[ $EUID -ne 0 ]] || die "Run this as your user, not root; it uses sudo where needed."

set_flag WITH_DESKTOP 1

if has_flag WITH_DESKTOP; then
  detect_capabilities

  if is_dry_run; then
    plan flag "WITH_DESKTOP=1"
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
else
  # No desktop, so no hardware to detect and nothing optional to ask about.
  export WITH_GAMING=0 WITH_ANDROID=0
  if is_dry_run; then
    plan flag "WITH_DESKTOP=0"
  else
    # Docker's daemon needs systemd, which WSL starts only when asked to.
    if is_wsl && [[ $(</proc/1/comm) != systemd ]]; then
      die "systemd isn't running in this WSL distro. Add [boot] systemd=true to /etc/wsl.conf, run 'wsl --shutdown' from Windows, then run this again."
    fi
    log_info "Installing the terminal setup only (no desktop)."
  fi
fi

record_profile

for module in installer/modules/*.sh; do
  bash "$module"
done

if ! is_dry_run; then
  if has_flag WITH_DESKTOP; then
    log_info "Installation complete. Reboot to start from a clean state."
  else
    log_info "Installation complete. Open a new terminal to start fish."
  fi
fi
