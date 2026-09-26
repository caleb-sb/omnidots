#!/usr/bin/env bash

wget2 https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip

mkdir -p ~/.local/share/fonts

unzip ./JetBrainsMono.zip -d ~/.local/share/fonts

rm ./JetBrainsMono.zip

# Icon font for the quickshell bar (config/qs-bar)
wget2 -O ~/.local/share/fonts/MaterialSymbolsRounded.ttf \
  'https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf'

fc-cache -fv
