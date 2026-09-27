# Shell basics. The env vars GUI apps need are set by Hyprland, not here.
set -g fish_greeting
set -gx EDITOR nvim

# Claude Code and the release binaries the installer fetches live here.
if test -d ~/.local/bin
    fish_add_path -g ~/.local/bin
end
