# pnpm installs itself in $PNPM_HOME/bin. The Node it manages (`pnpm env`) is
# linked in $PNPM_HOME itself, which the pnpm 12 installer no longer adds to
# PATH, so both go on it.
set -l pnpm_home $PNPM_HOME
if not set -q pnpm_home[1]
    set -l data_home ~/.local/share
    set -q XDG_DATA_HOME[1]; and set data_home $XDG_DATA_HOME
    set pnpm_home $data_home/pnpm
end
if test -d $pnpm_home
    set -gx PNPM_HOME $pnpm_home
    fish_add_path -g $PNPM_HOME/bin $PNPM_HOME
end
