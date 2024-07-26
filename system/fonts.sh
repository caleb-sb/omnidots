#!/usr/bin/env bash

wget2 https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip

mkdir -p ~/.local/share/fonts

unzip ~/JetBrainsMono.zip -d ~/.local/share/fonts

rm JetBrainsMono.zip

fc-cache -fv
