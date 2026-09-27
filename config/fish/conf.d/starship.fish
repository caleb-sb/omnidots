# starship is installed in ~/.local/bin, which env.fish (loaded first; conf.d
# goes in name order) puts on PATH.
if status is-interactive; and test "$TERM" != dumb; and command -q starship
    starship init fish | source
end
