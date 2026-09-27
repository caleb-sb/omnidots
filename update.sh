#!/usr/bin/env bash
#
# Refreshes everything that doesn't come from a dnf repo, skipping anything
# already at its latest release.
#
# Usage: ./update.sh [--dry-run]
#   --dry-run  print the plan to stdout, one action per line, and change nothing

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=installer/lib.sh
source installer/lib.sh

# The installer runs these modules too, for the first install.
MODULES=(
  installer/modules/80-releases.sh
)

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      sed -n '3,7s/^# \{0,1\}//p' "${BASH_SOURCE[0]##*/}"
      exit 0
      ;;
    *) die "Unknown argument: $arg" ;;
  esac
done
export DRY_RUN

[[ $EUID -ne 0 ]] || die "Run this as your user, not root; it uses sudo where needed."

for module in "${MODULES[@]}"; do
  bash "$module"
done
