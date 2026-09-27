# rustup is installed with --no-modify-path; this is the PATH it would add.
set -q CARGO_HOME; or set -l CARGO_HOME ~/.cargo
if test -d $CARGO_HOME/bin
    fish_add_path -g $CARGO_HOME/bin
end
