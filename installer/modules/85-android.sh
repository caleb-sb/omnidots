#!/usr/bin/env bash
#
# The optional Android module, when chosen (WITH_ANDROID=1): Android Studio
# from Google's official Linux tarball, unpacked into /opt/android-studio,
# where the fish config expects it, with a desktop entry. It's skipped when
# it's already at the latest release. update.sh runs this again to keep it
# current, but only when Android Studio is installed.
#
# Input, overridable so tests run offline:
#   OMNIDOTS_RELEASES_DIR  recorded release responses (default: the network)

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# The download page links the latest stable tarball, whose path holds the
# version: …/ide-zips/<version>/android-studio-<codename>-linux.tar.gz. The
# unpacked tree only carries the IDE's build number, so the installed version
# is recorded next to it.
DOWNLOAD_PAGE=https://developer.android.com/studio
VERSION_FILE="$ANDROID_STUDIO_DIR/.omnidots-version"
# Its own name, so a desktop entry that Android Studio's "Create Desktop
# Entry" wrote in ~/.local/share/applications takes precedence over this one.
DESKTOP_ENTRY=/usr/local/share/applications/android-studio.desktop

# unpack_android_studio <version> <url> — replace ANDROID_STUDIO_DIR with the
# tarball's contents. It's unpacked next to the old install, not in /tmp,
# which is a small tmpfs, and swapped in once complete.
unpack_android_studio() {
  local version="$1" url="$2" staging="$ANDROID_STUDIO_DIR.new"
  sudo rm -rf "$staging"
  sudo mkdir -p "$staging"
  curl -fsSL "$url" | sudo tar -xz --no-same-owner --strip-components=1 -C "$staging"
  printf '%s\n' "$version" | sudo tee "$staging/.omnidots-version" >/dev/null
  sudo rm -rf "$ANDROID_STUDIO_DIR"
  sudo mv "$staging" "$ANDROID_STUDIO_DIR"
}

write_desktop_entry() {
  sudo mkdir -p "${DESKTOP_ENTRY%/*}"
  sudo tee "$DESKTOP_ENTRY" >/dev/null <<ENTRY
[Desktop Entry]
Type=Application
Name=Android Studio
Exec=$ANDROID_STUDIO_DIR/bin/studio
Icon=$ANDROID_STUDIO_DIR/bin/studio.svg
Categories=Development;IDE;
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-studio
ENTRY
}

has_flag WITH_ANDROID || exit 0

log_info "Installing Android Studio"

url="$(fetch "$DOWNLOAD_PAGE" |
  grep -oE 'https://[^"]+/android-studio-[^"/]+-linux\.tar\.gz' | head -n 1)" ||
  die "No Linux tarball linked from $DOWNLOAD_PAGE"
version="${url%/*}"
version="${version##*/}"
[[ $version =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "No version in the tarball URL $url"
installed=
if [[ -r $VERSION_FILE ]]; then
  read -r installed <"$VERSION_FILE" || installed=
fi

is_current android-studio "$installed" "$version" && exit 0
act release "android-studio $version $url -> $ANDROID_STUDIO_DIR" \
  unpack_android_studio "$version" "$url"
act conf "$DESKTOP_ENTRY Exec=$ANDROID_STUDIO_DIR/bin/studio" write_desktop_entry
