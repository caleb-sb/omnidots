#!/bin/bash
# 💫 https://github.com/JaKooLit 💫 #
# COPR repo and tweaking of dnf #

# COPR Repos and packages needed from them
# solopasha/hyprland - most packages
# erikreider/SwayNotificationCenter swaync

# List of COPR repositories to be added and enabled
COPR_REPOS=(
  solopasha/hyprland
  erikreider/SwayNotificationCenter
  atim/starship
)

# Function to add dnf config if not present in a file
add_config_if_not_present() {
  local file="$1"
  local config="$2"
  grep -qF "$config" "$file" || echo "$config" | sudo tee -a "$file" >/dev/null
}

# Check and add configuration settings to /etc/dnf/dnf.conf
add_config_if_not_present "/etc/dnf/dnf.conf" "max_parallel_downloads=5"
add_config_if_not_present "/etc/dnf/dnf.conf" "fastestmirror=True"
add_config_if_not_present "/etc/dnf/dnf.conf" "defaultyes=True"

# enabling 3rd party repo
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm &&

  # Enable COPR Repositories
  for repo in "${COPR_REPOS[@]}"; do
    sudo dnf copr enable -y "$repo" 2>&1 || {
      printf "%s - Failed to enable necessary copr repos\n" " "
      exit 1
    }
  done

# Update package cache and install packages from COPR Repos
sudo dnf update -y

clear
