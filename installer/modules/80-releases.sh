#!/usr/bin/env bash
#
# Tools installed from upstream releases instead of a dnf repo: starship and
# lazygit binaries into ~/.local/bin, and on a desktop the OpenWhispr, Proton
# Mail and Proton Pass rpms.
# Each is skipped when it's already at the latest release. update.sh runs
# this again to keep them current.
#
# Input, overridable so tests run offline:
#   OMNIDOTS_RELEASES_DIR  recorded release responses (default: the network)

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Proton lists each Linux app's releases, newest first, with a download URL
# and SHA-512 for each package format. Betas and early-access builds, and
# stable ones still rolling out (to a fraction of users, in Mail's
# RolloutProportion or Pass's RolloutPercentage), are skipped.
PROTON_MAIL_VERSIONS=https://proton.me/download/mail/linux/version.json
PROTON_PASS_VERSIONS=https://proton.me/download/PassDesktop/linux/x64/version.json

# proton_app <package> <version.json url> — install or update the app from
# Proton's newest stable rpm that has reached everyone, checksum-verified.
proton_app() {
  local pkg="$1" feed="$2" latest version url sha512
  latest="$(fetch "$feed" | jq -r '
    first(.Releases[]
      | select(.CategoryName == "Stable")
      | select((.RolloutProportion // .RolloutPercentage // 1) >= 1))
    | .Version as $version
    | first(.File[] | select(.Url | endswith(".rpm")))
    | $version, .Url, (.Sha512CheckSum // "")')"
  { read -r version && read -r url && read -r sha512; } <<<"$latest" ||
    die "No stable $pkg rpm in $feed"
  install_release_rpm "$pkg" "$version" "$url" "$sha512"
}

log_info "Installing tools from upstream releases"

github_release starship/starship starship starship-x86_64-unknown-linux-musl.tar.gz
github_release jesseduffield/lazygit lazygit 'lazygit_{version}_linux_x86_64.tar.gz'
has_flag WITH_DESKTOP || exit 0
github_release OpenWhispr/openwhispr open-whispr 'OpenWhispr-{version}-linux-x86_64.rpm'
proton_app proton-mail "$PROTON_MAIL_VERSIONS"
proton_app proton-pass "$PROTON_PASS_VERSIONS"
