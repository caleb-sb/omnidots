#!/usr/bin/env bash
#
# Tools for the backlight and Bluetooth adapter, when the machine has them.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

has_flag WITH_DESKTOP || exit 0

lists=()
if has_flag HAS_BACKLIGHT; then
  lists+=(backlight)
fi
if has_flag HAS_BLUETOOTH; then
  lists+=(bluetooth)
fi

((${#lists[@]} == 0)) || install_package_list "${lists[@]}"
