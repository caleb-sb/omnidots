#!/usr/bin/env bash

sudo dnf install -y dnf-plugins-core

sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

sudo dnf install fedora-workstation-repositories

sudo dnf config-manager setopt google-chrome.enabled=1

# sudo dnf install -y snapd

sudo dnf install -y flatpak

sudo dnf install -y google-chrome-stable
