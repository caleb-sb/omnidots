# Use kitty's ssh kitten when running inside kitty, so remote hosts get working
# terminfo and the tmux config from ~/.config/kitty/ssh.conf. Expands visibly,
# and leaves scp/rsync alone.
if set -q KITTY_WINDOW_ID
    abbr -a ssh 'kitten ssh'
end
