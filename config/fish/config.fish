# Only execute this file once per shell.
set -q __fish_home_manager_config_sourced; and exit
set -g __fish_home_manager_config_sourced 1

function setup_hm_session_vars
    # Only source this once.
    if [ -n "$__HM_SESS_VARS_SOURCED" ]
        return
    end
    set -gx __HM_SESS_VARS_SOURCED 1
    set -gx EDITOR nvim
    set -gx GTK2_RC_FILES '/home/caleb/.gtkrc-2.0'
    set -gx QT_QPA_PLATFORMTHEME qt5ct
    set -gx QT_STYLE_OVERRIDE kvantum
    set -gx XDG_CACHE_HOME '/home/caleb/.cache'
    set -gx XDG_CONFIG_HOME '/home/caleb/.config'
    set -gx XDG_DATA_HOME '/home/caleb/.local/share'
    set -gx XDG_STATE_HOME '/home/caleb/.local/state'
end
setup_hm_session_vars

set fish_greeting

status is-login; and begin

    # Login shell initialisation


end

status is-interactive; and begin

    # Abbreviations


    # Aliases
    alias l 'eza -lh --icons=auto'
    alias ld 'eza -lhD --icons=auto'
    alias lg lazygit
    alias ll 'eza -lha --icons=auto --sort=name --group-directories-first'
    alias ls 'eza -1'

    # Interactive shell initialisation
    if test "$TERM" != dumb
        eval (starship init fish)

    end

    if set -q KITTY_INSTALLATION_DIR
        set --global KITTY_SHELL_INTEGRATION no-rc
        source "$KITTY_INSTALLATION_DIR/shell-integration/fish/vendor_conf.d/kitty-shell-integration.fish"
        set --prepend fish_complete_path "$KITTY_INSTALLATION_DIR/shell-integration/fish/vendor_completions.d"
    end
end
