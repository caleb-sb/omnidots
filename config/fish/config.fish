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
    alias lg lazygit

    # Launch Hyprland through its watchdog supervisor (0.56+) rather than bare,
    # which otherwise warns "started without start-hyprland".
    alias Hyprland start-hyprland
    alias hyprland start-hyprland

    # Interactive shell initialisation
    if test "$TERM" != dumb
        starship init fish | source

    end

    if set -q KITTY_INSTALLATION_DIR
        set --global KITTY_SHELL_INTEGRATION no-rc
        source "$KITTY_INSTALLATION_DIR/shell-integration/fish/vendor_conf.d/kitty-shell-integration.fish"
        set --prepend fish_complete_path "$KITTY_INSTALLATION_DIR/shell-integration/fish/vendor_completions.d"
    end
end

# pnpm
set -gx PNPM_HOME '/home/caleb/.local/share/pnpm'
if not string match -q -- "$PNPM_HOME/bin" $PATH
  set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end

# Node installed by `pnpm env` is linked in $PNPM_HOME itself, which the pnpm 12
# installer no longer adds to PATH (it only adds $PNPM_HOME/bin).
if not contains -- "$PNPM_HOME" $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

set -gx CLAUDE_HOME "/home/caleb/.local/bin"
if not string match -q -- $CLAUDE_HOME $PATH
    set -gx PATH "$CLAUDE_HOME" $PATH
end

set -gx JAVA_HOME /opt/android-studio/jbr
set -gx ANDROID_HOME "$HOME/Android/Sdk"
set -gx NDK_HOME "$ANDROID_HOME/ndk/$(ls -1 $ANDROID_HOME/ndk)"
set -gx ANDROID_AVD_HOME "$HOME/.config/.android/avd"
