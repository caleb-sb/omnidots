#!/usr/bin/env bash
#
# Tools installed from upstream releases instead of a dnf repo: starship and
# lazygit binaries into ~/.local/bin, and the OpenWhispr and Proton Mail rpms.
# Each is skipped when it's already at the latest release. update.sh runs
# this again to keep them current.
#
# Input, overridable so tests run offline:
#   OMNIDOTS_RELEASES_DIR  recorded release responses (default: the network)

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Proton lists its Linux Mail releases, newest first, with a download URL for
# each package format. Early-access builds only reach part of the users.
PROTON_MAIL_VERSIONS=https://proton.me/download/mail/linux/version.json

# proton_mail — install or update Proton Mail from Proton's latest stable rpm.
proton_mail() {
  local latest version url
  latest="$(fetch "$PROTON_MAIL_VERSIONS" | jq -r '
    first(.Releases[] | select(.CategoryName == "Stable"))
    | .Version, first(.File[].Url | select(endswith(".rpm")))')"
  { read -r version && read -r url; } <<<"$latest" ||
    die "No stable Proton Mail rpm in $PROTON_MAIL_VERSIONS"
  install_release_rpm proton-mail "$version" "$url"
}

log_info "Installing tools from upstream releases"

github_release starship/starship starship starship-x86_64-unknown-linux-musl.tar.gz
github_release jesseduffield/lazygit lazygit 'lazygit_{version}_linux_x86_64.tar.gz'
github_release OpenWhispr/openwhispr open-whispr 'OpenWhispr-{version}-linux-x86_64.rpm'
proton_mail
