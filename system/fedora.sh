#!/usr/bin/env bash

sudo dnf install snapd

sudo dnf install fedora-workstation-repositories

sudo dnf config-manager --set-enabled google-chrome
