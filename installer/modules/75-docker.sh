#!/usr/bin/env bash
#
# Rootful Docker Engine from Docker's repo, with the buildx and compose
# plugins. The daemon starts at boot, and the user joins the docker group so
# docker works without sudo from the next login.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

log_info "Installing Docker"

install_package_list docker
run sudo systemctl enable --now docker

user="$(id -un)"
# Only when not already a member, so a re-run changes nothing.
if is_dry_run || [[ " $(id -nG "$user") " != *" docker "* ]]; then
  run sudo usermod -aG docker "$user"
  is_dry_run || log_info "Added $user to the docker group; it takes effect at the next login."
fi
