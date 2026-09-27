#!/usr/bin/env bash
#
# Runs shellcheck over every installer shell script, then the bats suite.
# Dev-only: sudo dnf install ShellCheck bats

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

mapfile -t scripts < <(git ls-files --cached --others --exclude-standard \
  'install.sh' 'update.sh' 'migrate.sh' 'installer/*.sh' 'tests/*.sh' 'tests/*.bats')

shellcheck --external-sources "${scripts[@]}"
bats tests/
