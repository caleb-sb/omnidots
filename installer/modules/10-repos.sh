#!/usr/bin/env bash
#
# dnf settings and third-party repositories.

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

DNF_CONF=/etc/dnf/dnf.conf

COPRS=(
  lionheartp/Hyprland         # the Hyprland wiki's Fedora source
  errornointernet/quickshell
)

# set_dnf_option <key> <value> — set a [main] option in dnf.conf.
set_dnf_option() {
  local key="$1" value="$2"
  if is_dry_run; then
    plan conf "$DNF_CONF $key=$value"
  elif grep -q "^$key=" "$DNF_CONF"; then
    sudo sed -i "s/^$key=.*/$key=$value/" "$DNF_CONF"
  else
    printf '%s=%s\n' "$key" "$value" | sudo tee -a "$DNF_CONF" >/dev/null
  fi
}

# unset_dnf_option <key> — drop an option from dnf.conf if present.
unset_dnf_option() {
  act conf "$DNF_CONF unset $1" sudo sed -i "/^$1=/d" "$DNF_CONF"
}

enable_rpmfusion() {
  if is_dry_run; then
    plan repo rpmfusion-free
    plan repo rpmfusion-nonfree
    return
  fi
  local fedora
  fedora="$(rpm -E %fedora)"
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fedora.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm"
}

enable_copr() {
  act repo "copr:$1" sudo dnf copr enable -y "$1"
}

log_info "Configuring dnf and repositories"

set_dnf_option max_parallel_downloads 10
set_dnf_option defaultyes True
# dnf5 ignores fastestmirror; older versions of this installer set it.
unset_dnf_option fastestmirror

enable_rpmfusion
for copr in "${COPRS[@]}"; do
  enable_copr "$copr"
done
