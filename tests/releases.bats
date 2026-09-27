#!/usr/bin/env bats
#
# Installing a release rpm for real (installer/lib.sh's install_release_rpm),
# with its published SHA-512 checked first. curl, rpm and sudo are stubs:
# curl "downloads" a local file, and sudo only records what it would run.

bats_require_minimum_version 1.5.0

setup() {
  STUBS="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$STUBS"
  touch "$CALLS"
  RPM_FILE="$BATS_TEST_TMPDIR/download.rpm"
  echo "pretend rpm" >"$RPM_FILE"
  GOOD_SUM="$(sha512sum "$RPM_FILE" | cut -d' ' -f1)"

  # curl -fsSL -o <file> <url>: copies the pretend download to <file>.
  cat >"$STUBS/curl" <<EOF
#!/bin/sh
while [ \$# -gt 0 ]; do
  case "\$1" in -o) out="\$2"; shift ;; esac
  shift
done
cp "$RPM_FILE" "\$out"
EOF
  # Nothing is installed.
  # shellcheck disable=SC2016 # expands in the stub
  printf '#!/bin/sh\necho "package $3 is not installed"; exit 1\n' >"$STUBS/rpm"
  printf '#!/bin/sh\necho "sudo $*" >>"%s"\n' "$CALLS" >"$STUBS/sudo"
  chmod +x "$STUBS"/*
}

# install <sha512> — install_release_rpm for a proton-pass release, for real.
install() {
  # shellcheck disable=SC2016 # expands in the inner bash
  run --separate-stderr env PATH="$STUBS:$PATH" DRY_RUN=0 bash -c '
    source "$1/installer/lib.sh"
    install_release_rpm proton-pass 1.40.2 https://example.com/proton-pass-1.40.2-1.x86_64.rpm "$2"
  ' _ "$BATS_TEST_DIRNAME/.." "$1"
}

@test "an rpm matching its published checksum is installed from the verified download" {
  install "$GOOD_SUM"
  [ "$status" -eq 0 ]
  run cat "$CALLS"
  [[ $output == "sudo dnf install -y /"*/proton-pass-1.40.2-1.x86_64.rpm ]]
}

@test "an rpm that doesn't match its checksum isn't installed" {
  install "$(printf '0%.0s' {1..128})"
  [ "$status" -ne 0 ]
  [[ $stderr == *"checksum"* ]]
  [ ! -s "$CALLS" ]
}

@test "without a published checksum, dnf installs straight from the URL" {
  install ""
  [ "$status" -eq 0 ]
  run cat "$CALLS"
  [ "$output" = "sudo dnf install -y https://example.com/proton-pass-1.40.2-1.x86_64.rpm" ]
}
