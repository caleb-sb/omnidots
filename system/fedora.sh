#!/usr/bin/env bash

sudo dnf install fedora-workstation-repositories

sudo dnf config-manager --set-enabled google-chrome

sudo dnf install -y snapd

sudo dnf install -y flatpak

sudo dnf install -y google-chrome-stable
