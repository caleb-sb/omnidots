#!/usr/bin/env bash
#
# The optional gaming module, when chosen (WITH_GAMING=1): Steam from RPM
# Fusion, and Discord and Heroic from Flathub, which 60-flatpaks.sh adds.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

APPS=(
  com.discordapp.Discord
  com.heroicgameslauncher.hgl
)

has_flag WITH_GAMING || exit 0

log_info "Installing the gaming module"

install_package_list gaming
install_flatpaks "${APPS[@]}"
