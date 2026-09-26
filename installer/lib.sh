# shellcheck shell=bash
#
# Shared helpers for the installer and its modules. Source this file; don't
# execute it.
#
# Dry-run: with DRY_RUN=1 nothing is executed. Every action prints one plan
# line to stdout instead, as `<kind>: <detail>` (flag, conf, repo, pkg, backup,
# link, run). The tests assert on these lines, so keep the format stable.
# Logging goes to stderr so it never mixes with the plan.

OMNIDOTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES_DIR="$OMNIDOTS_ROOT/installer/packages"
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

# install_package_list <name> — install packages/<name>.txt in one transaction.
# Lists hold one package per line; `#` starts a comment.
install_package_list() {
  local file="$PACKAGES_DIR/$1.txt"
  [[ -f $file ]] || die "Package list not found: $file"
  local -a pkgs
  mapfile -t pkgs < <(awk '{ sub(/#.*/, "") } NF { print $1 }' "$file")
  log_info "Installing the $1 package list (${#pkgs[@]} packages)"
  install_packages "${pkgs[@]}"
}
