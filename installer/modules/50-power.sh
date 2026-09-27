#!/usr/bin/env bash
#
# CPU power profile. Without a battery, tuned is pinned to
# throughput-performance and there's no UI for it. With one, tuned-ppd serves
# the power-profiles-daemon D-Bus API that qs-bar's power panel switches, so no
# profile is pinned here.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

PERFORMANCE_PROFILE=throughput-performance

log_info "Setting up the CPU power profile"

if has_flag HAS_BATTERY; then
  install_package_list battery
  run sudo systemctl enable --now tuned tuned-ppd
else
  install_packages tuned
  run sudo systemctl enable --now tuned
  # Only when it isn't already active, so a re-run changes nothing.
  if is_dry_run || [[ $(tuned-adm active 2>/dev/null) != *": $PERFORMANCE_PROFILE" ]]; then
    run sudo tuned-adm profile "$PERFORMANCE_PROFILE"
  fi
fi
