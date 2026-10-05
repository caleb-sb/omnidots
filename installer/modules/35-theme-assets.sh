#!/usr/bin/env bash
#
# Fonts and theme assets, fetched instead of kept in git. Tela circle icons,
# Bibata-Modern-Ice cursors (XCursor and hyprcursor) and Fausto Korpsvart's
# Tokyonight GTK theme come at the versions pinned below, into the user's icon
# and theme dirs. The JetBrainsMono Nerd Font comes from its latest release,
# and Material Symbols Rounded, which qs-bar uses, from the latest commit that
# changed it, into the user's font dir. Each is skipped when that version is
# already there, and the font cache is rebuilt when a font changed. update.sh
# runs this again to refresh the fonts and install new pins.
#
# Input, overridable so tests run offline:
#   OMNIDOTS_RELEASES_DIR  recorded release responses (default: the network)

set -euo pipefail
# shellcheck source=installer/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

has_flag WITH_DESKTOP || exit 0

# Pins. Bump one to have the next run or update.sh install it.
TELA_ICONS_TAG=2026-07-07                 # vinceliuice/Tela-circle-icon-theme
BIBATA_TAG=v2.0.7                         # ful1e5/Bibata_Cursor
BIBATA_HYPRCURSOR_TAG=v1.1                # LOSEARDES77/Bibata-Cursor-hyprcursor
TOKYONIGHT_GTK_COMMIT=6c340e058e84c1975a038a8e5d1e384477225dc0 # Fausto-Korpsvart/Tokyonight-GTK-Theme

# The XDG data dirs, which hyprcursor searches and GTK reads alongside the
# legacy ~/.icons and ~/.themes.
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
ICONS_DIR="$DATA_DIR/icons"
THEMES_DIR="$DATA_DIR/themes"
FONTS_DIR="$DATA_DIR/fonts"
# One theme dir holds both cursor formats, so XCURSOR_THEME and
# HYPRCURSOR_THEME name the same theme.
BIBATA_DIR="$ICONS_DIR/Bibata-Modern-Ice"

# Google publishes Material Symbols only in its repo, with no releases.
MATERIAL_SYMBOLS_FILE='variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf'
MATERIAL_SYMBOLS_COMMITS="https://github.com/google/material-design-icons/commits/master/$MATERIAL_SYMBOLS_FILE.atom"

FONTS_CHANGED=0

# install_asset <name> <version> <url> <dir> <install-fn> — unless <dir>
# records <name> at <version>, run <install-fn> <url> <dir> and record it
# there. Theme and font dirs carry no usable version of their own, hence the
# marker file.
install_asset() {
  local name="$1" version="$2" url="$3" dir="$4" marker="$4/.omnidots-$1" installed=
  if [[ -r $marker ]]; then
    read -r installed <"$marker" || installed=
  fi
  is_current "$name" "$installed" "$version" && return
  act release "$name $version $url -> $dir" install_and_record "$@"
  [[ $dir != "$FONTS_DIR"/* ]] || FONTS_CHANGED=1
}

install_and_record() {
  local name="$1" version="$2" url="$3" dir="$4" install_fn="$5"
  "$install_fn" "$url" "$dir"
  mkdir -p "$dir"
  printf '%s\n' "$version" >"$dir/.omnidots-$name"
}

# with_source <url> <cmd...> — run the command in a temp dir holding the
# unpacked source tarball, then remove it.
with_source() {
  local url="$1" tmp
  shift
  tmp="$(mktemp -d)"
  curl -fsSL "$url" | tar -xz --strip-components=1 -C "$tmp"
  (cd "$tmp" && "$@")
  rm -rf "$tmp"
}

# The purple folders, as Tela-circle-purple plus its -light and -dark
# variants.
install_tela() { with_source "$1" bash ./install.sh -d "$ICONS_DIR" purple; }

# The Night palette is the theme's default colorscheme (window background
# #1a1b26); its tweaks are Moon, Storm and a darker "black". Only the dark
# variant is installed, as Tokyonight-Dark, and --libadwaita links its
# gtk-4.0 CSS into ~/.config/gtk-4.0 for libadwaita apps.
install_tokyonight_gtk() {
  with_source "$1" bash ./themes/install.sh -d "$THEMES_DIR" --libadwaita -c dark
}

# Only the cursors dir is replaced, which keeps the hyprcursor files next to it.
install_bibata() {
  rm -rf "$BIBATA_DIR/cursors"
  mkdir -p "$ICONS_DIR"
  curl -fsSL "$1" | tar -xJ -C "$ICONS_DIR"
}

install_bibata_hyprcursor() {
  rm -rf "$BIBATA_DIR/hyprcursors"
  mkdir -p "$BIBATA_DIR"
  curl -fsSL "$1" | tar -xz -C "$BIBATA_DIR"
}

# Just the fonts, without the license and readme.
install_nerd_font() {
  rm -rf "$2"
  mkdir -p "$2"
  curl -fsSL "$1" | tar -xJ -C "$2" --wildcards '*.ttf'
}

install_material_symbols() {
  mkdir -p "$2"
  curl -fsSL -o "$2/MaterialSymbolsRounded.ttf" "$1"
}

log_info "Installing icon, cursor and GTK themes"

install_asset tela-circle-icons "$TELA_ICONS_TAG" \
  "https://github.com/vinceliuice/Tela-circle-icon-theme/archive/refs/tags/$TELA_ICONS_TAG.tar.gz" \
  "$ICONS_DIR/Tela-circle-purple" install_tela
install_asset bibata-cursors "${BIBATA_TAG#v}" \
  "https://github.com/ful1e5/Bibata_Cursor/releases/download/$BIBATA_TAG/Bibata-Modern-Ice.tar.xz" \
  "$BIBATA_DIR" install_bibata
install_asset bibata-hyprcursors "${BIBATA_HYPRCURSOR_TAG#v}" \
  "https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor/releases/download/$BIBATA_HYPRCURSOR_TAG/hypr_Bibata-Modern-Ice.tar.gz" \
  "$BIBATA_DIR" install_bibata_hyprcursor
install_asset tokyonight-gtk "$TOKYONIGHT_GTK_COMMIT" \
  "https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme/archive/$TOKYONIGHT_GTK_COMMIT.tar.gz" \
  "$THEMES_DIR/Tokyonight-Dark" install_tokyonight_gtk

log_info "Installing fonts"

tag="$(latest_github_tag ryanoasis/nerd-fonts)"
install_asset jetbrains-mono-nerd-font "${tag#v}" \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/$tag/JetBrainsMono.tar.xz" \
  "$FONTS_DIR/JetBrainsMonoNerdFont" install_nerd_font

# The feed lists the commits that changed the file, newest first. The font is
# fetched as of that commit, so the version recorded is the one installed.
commits="$(fetch "$MATERIAL_SYMBOLS_COMMITS" | grep -oE 'Grit::Commit/[0-9a-f]{40}')" ||
  die "No commits in $MATERIAL_SYMBOLS_COMMITS"
commit="${commits%%$'\n'*}"
commit="${commit##*/}"
install_asset material-symbols-rounded "$commit" \
  "https://raw.githubusercontent.com/google/material-design-icons/$commit/$MATERIAL_SYMBOLS_FILE" \
  "$FONTS_DIR/MaterialSymbolsRounded" install_material_symbols

if ((FONTS_CHANGED)); then
  run fc-cache -f
fi
