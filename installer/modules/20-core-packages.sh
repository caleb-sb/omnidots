#!/usr/bin/env bash
#
# Packages every machine gets, regardless of hardware: the terminal list, and
# on a desktop the desktop list too, in one transaction.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

lists=(terminal)
if has_flag WITH_DESKTOP; then
  lists+=(desktop)
fi

install_package_list "${lists[@]}"
