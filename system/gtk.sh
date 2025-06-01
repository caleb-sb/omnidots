#!/usr/bin/env bash

sudo dnf install -y gtk-murrine-engine

mkdir ~/.icons
cp -rf ./gtk-icons/. ~/.icons

mkdir ~/.themes
cp -rf ./gtk-themes/. ~/.themes
