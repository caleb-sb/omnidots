# shellcheck shell=bash
#
# Shared helpers for the installer and its modules. Source this file; don't
# execute it.
#
# Dry-run: with DRY_RUN=1 nothing is executed. Every action prints one plan
# line to stdout instead, as `<kind>: <detail>` (flag, conf, repo, pkg, swap,
# backup, link, run, wait, gpu-order, flatpak for a Flathub app ID, ask for a
# command the real run offers and the user can skip, release for an upstream
# release to install: `<name> <version> <url>`, an rpm dnf installs, or with
# `-> <path>` a binary put there, and current for one already at the latest
# version, which is skipped). The tests assert
# on these lines, so keep the format stable.
# Logging goes to stderr so it never mixes with the plan.

OMNIDOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="$OMNIDOTS_ROOT/installer/packages"
LOCAL_BIN="$HOME/.local/bin"
: "${DRY_RUN:=0}"

log_info() { printf '\e[36m[info]\e[0m %s\n' "$*" >&2; }
log_warn() { printf '\e[33m[warn]\e[0m %s\n' "$*" >&2; }
log_error() { printf '\e[31m[error]\e[0m %s\n' "$*" >&2; }

die() {
  log_error "$@"
  exit 1
}

is_dry_run() { [[ $DRY_RUN == 1 ]]; }

# plan <kind> <detail...> — print one line of the dry-run plan.
plan() {
  local kind="$1"
  shift
  printf '%s: %s\n' "$kind" "$*"
}

# act <kind> <detail> <cmd...> — run the command, or in dry-run print
# `<kind>: <detail>` instead.
act() {
  local kind="$1" detail="$2"
  shift 2
  if is_dry_run; then
    plan "$kind" "$detail"
  else
    "$@"
  fi
}

# run <cmd...> — run a command, or print it as a `run:` line in dry-run.
run() { act run "$*" "$@"; }

# has_flag <HAS_*> — true when the capability flag is set to 1.
has_flag() { [[ ${!1:-0} == 1 ]]; }

# install_packages <pkg...> — install packages in a single dnf transaction.
install_packages() {
  (($#)) || return 0
  if is_dry_run; then
    local pkg
    for pkg in "$@"; do plan pkg "$pkg"; done
    return
  fi
  sudo dnf install -y "$@"
}

# install_flatpaks <app-id...> — install apps from the Flathub remote, which
# 60-flatpaks.sh adds, system-wide in one transaction. Installed apps are
# skipped.
install_flatpaks() {
  (($#)) || return 0
  if is_dry_run; then
    local app
    for app in "$@"; do plan flatpak "$app"; done
    return
  fi
  sudo flatpak install -y --noninteractive flathub "$@"
}

# package_list <name> — print the packages in packages/<name>.txt, one per
# line. Lists hold one package per line; `#` starts a comment.
package_list() {
  local file="$PACKAGES_DIR/$1.txt"
  [[ -f $file ]] || die "Package list not found: $file"
  awk '{ sub(/#.*/, "") } NF { print $1 }' "$file"
}

# fetch <url> — print a URL's body. With OMNIDOTS_RELEASES_DIR set, print the
# response recorded at <dir>/<url without https://> instead, so tests run
# offline. Release lookups go through this, and run in dry-run too: finding
# out what's new is the plan.
fetch() {
  if [[ -n ${OMNIDOTS_RELEASES_DIR:-} ]]; then
    cat "$OMNIDOTS_RELEASES_DIR/${1#https://}"
  else
    curl -fsSL "$1"
  fi
}

# latest_github_tag <owner/repo> — the tag of the repo's latest release, read
# from where /releases/latest redirects to (…/releases/tag/<tag>) rather than
# from the API, which allows 60 unauthenticated requests an hour. A recorded
# response holds that redirect target.
latest_github_tag() {
  local url="https://github.com/$1/releases/latest" target
  if [[ -n ${OMNIDOTS_RELEASES_DIR:-} ]]; then
    target="$(fetch "$url")"
  else
    target="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$url")"
  fi
  [[ $target == */releases/tag/* ]] || die "No release found for $1"
  printf '%s\n' "${target##*/}"
}

# is_current <name> <installed> <latest> — true, logging or planning
# `current:`, when the installed version is the latest.
is_current() {
  [[ $2 == "$3" ]] || return 1
  if is_dry_run; then
    plan current "$1 $2"
  else
    log_info "$1 $2 is the latest release"
  fi
}

# install_release_binary <name> <version> <tarball-url> — put the <name>
# binary from a release tarball into LOCAL_BIN, unless the one there already
# reports <version>. Only LOCAL_BIN counts: a copy elsewhere on PATH, like an
# old COPR build, is not what this installs.
install_release_binary() {
  local name="$1" version="$2" url="$3" dest="$LOCAL_BIN/$1" installed=
  if [[ -x $dest ]]; then
    installed="$("$dest" --version | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1)" ||
      installed=
  fi
  is_current "$name" "$installed" "$version" && return
  if is_dry_run; then
    plan release "$name $version $url -> $dest"
    return
  fi
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$url" | tar -xz -C "$tmp" "$name"
  install -D -m 755 "$tmp/$name" "$dest"
  rm -rf "$tmp"
}

# install_release_rpm <package> <version> <rpm-url> — install or upgrade the
# package from a release rpm, unless that version is installed.
install_release_rpm() {
  local pkg="$1" version="$2" url="$3" installed
  installed="$(rpm -q --qf '%{VERSION}' "$pkg")" || installed=
  is_current "$pkg" "$installed" "$version" && return
  act release "$pkg $version $url" sudo dnf install -y "$url"
}

# github_release <owner/repo> <name> <asset> — install or update <name> from
# the repo's latest release: a binary from a .tar.gz asset, or the package
# from an .rpm asset. `{version}` in the asset name stands for the version,
# which is the tag without its `v` prefix.
github_release() {
  local repo="$1" name="$2" tag version url
  tag="$(latest_github_tag "$repo")"
  version="${tag#v}"
  url="https://github.com/$repo/releases/download/$tag/${3//\{version\}/$version}"
  case "$url" in
    *.rpm) install_release_rpm "$name" "$version" "$url" ;;
    *) install_release_binary "$name" "$version" "$url" ;;
  esac
}

# install_package_list <name...> — install the named lists in one transaction.
install_package_list() {
  local -a pkgs=()
  local name list
  for name in "$@"; do
    list="$(package_list "$name")"
    [[ -n $list ]] || continue
    mapfile -t -O "${#pkgs[@]}" pkgs <<<"$list"
  done
  log_info "Installing the $* package list${2:+s} (${#pkgs[@]} packages)"
  install_packages "${pkgs[@]}"
}
