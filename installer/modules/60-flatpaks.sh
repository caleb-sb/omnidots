#!/usr/bin/env bash
#
# Apps every machine gets from Flathub.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

FLATHUB_REPO_URL=https://dl.flathub.org/repo/flathub.flatpakrepo

APPS=(
  md.obsidian.Obsidian
  com.spotify.Client
  com.ultimaker.cura
)

log_info "Installing Flathub apps"

act repo flathub sudo flatpak remote-add --if-not-exists flathub "$FLATHUB_REPO_URL"
install_flatpaks "${APPS[@]}"
