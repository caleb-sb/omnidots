#!/usr/bin/env sh

# define functions

Wall_Set() {
  if [ -z $xtrans ]; then
    xtrans="grow"
  fi

  swww img /home/caleb/.config/swww/Catppuccin-Mocha/Staircase.png \
    --transition-bezier .43,1.19,1,.4 \
    --transition-type "$xtrans" \
    --transition-duration 0.7 \
    --transition-fps 60 \
    --invert-y \
    --transition-pos "$(hyprctl cursorpos)"
}

# check swww daemon and set wall
swww query
if [ $? -eq 1 ]; then
  swww init
fi

Wall_Set
