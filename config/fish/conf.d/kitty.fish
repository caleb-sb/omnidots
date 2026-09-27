# kitty's shell integration, loaded by hand (kitty.conf sets
# shell_integration no-rc so kitty doesn't touch this config).
if status is-interactive; and set -q KITTY_INSTALLATION_DIR
    set -g KITTY_SHELL_INTEGRATION no-rc
    source $KITTY_INSTALLATION_DIR/shell-integration/fish/vendor_conf.d/kitty-shell-integration.fish
    set -p fish_complete_path $KITTY_INSTALLATION_DIR/shell-integration/fish/vendor_completions.d
end
