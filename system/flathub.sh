#!/usr/bin/env bash

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install -y flathub md.obsidian.Obsidian
