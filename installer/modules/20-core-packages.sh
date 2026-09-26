#!/usr/bin/env bash
#
# Packages every machine gets, regardless of hardware.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

install_package_list core
