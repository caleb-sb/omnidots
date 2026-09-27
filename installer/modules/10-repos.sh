#!/usr/bin/env bash
#
# dnf settings and third-party repositories.
#
# Input, overridable so tests get a fixed Fedora release:
#   OMNIDOTS_OS_RELEASE  os-release file (default: /etc/os-release)

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

DNF_CONF=/etc/dnf/dnf.conf
REPOS_DIR=/etc/yum.repos.d

BRAVE_REPO_URL=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
DOCKER_REPO_URL=https://download.docker.com/linux/fedora/docker-ce.repo
# Proton ships one release rpm per Fedora release, each signed with that
# release's key. Its version is in the path Proton's install guide gives:
# https://protonvpn.com/support/official-linux-vpn-fedora
PROTONVPN_RELEASE_RPM=protonvpn-stable-release-1.0.4-1.noarch.rpm

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

# fedora_version — VERSION_ID from os-release, e.g. 44.
fedora_version() {
  local version
  version="$(awk -F= '$1 == "VERSION_ID" { gsub(/"/, "", $2); print $2 }' \
    "${OMNIDOTS_OS_RELEASE:-/etc/os-release}")"
  [[ -n $version ]] || die "No VERSION_ID in ${OMNIDOTS_OS_RELEASE:-/etc/os-release}"
  printf '%s\n' "$version"
}

# add_repo_file <name> <url> — add a vendor's .repo file, once. dnf names the
# file after the URL, and refuses to overwrite it on a re-run.
add_repo_file() {
  local name="$1" url="$2"
  if is_dry_run || [[ ! -f $REPOS_DIR/$name.repo ]]; then
    act repo "$name" sudo dnf config-manager addrepo --from-repofile="$url"
  fi
}

# enable_google_chrome — Fedora packages Google's repo, disabled.
enable_google_chrome() {
  install_packages fedora-workstation-repositories
  act repo google-chrome sudo dnf config-manager setopt google-chrome.enabled=1
}

# enable_protonvpn — install Proton's release rpm for this Fedora release, and
# show its signing key's fingerprint. dnf imports the key from the repo over
# HTTPS and verifies every package against it; the fingerprint is printed so
# it can be compared with Proton's install guide, not checked against a copy
# here, because the key differs per Fedora release.
enable_protonvpn() {
  local base url
  base="https://repo.protonvpn.com/fedora-$(fedora_version)-stable"
  url="$base/protonvpn-stable-release/$PROTONVPN_RELEASE_RPM"
  if is_dry_run; then
    plan repo "protonvpn $url"
    return
  fi
  rpm -q --quiet protonvpn-stable-release && return
  sudo dnf install -y "$url"
  log_info "Proton VPN's signing key, which dnf imports on the first Proton install:"
  curl -fsSL "$base/public_key.asc" | gpg --show-keys --with-fingerprint >&2 ||
    log_warn "Couldn't fetch Proton's key to show its fingerprint; dnf still verifies it."
}

enable_copr() {
  act repo "copr:$1" sudo dnf copr enable -y "$1"
}

log_info "Configuring dnf and repositories"

set_dnf_option max_parallel_downloads 10
set_dnf_option defaultyes True
# dnf5 ignores fastestmirror; older versions of this installer set it.
unset_dnf_option fastestmirror

# dnf5's copr and config-manager commands, used below (dnf-plugins-core
# is the dnf4 package).
install_packages dnf5-plugins

enable_rpmfusion
for copr in "${COPRS[@]}"; do
  enable_copr "$copr"
done
add_repo_file brave-browser "$BRAVE_REPO_URL"
enable_google_chrome
add_repo_file docker-ce "$DOCKER_REPO_URL"
enable_protonvpn
