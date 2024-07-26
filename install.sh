#!/usr/bin/env bash
#
if [[ $EUID -eq 0 ]]; then
  echo "This script should not be executed as root! Exiting......."
  exit 1
fi

echo "$(tput setaf 166)[WARNING]$(tput sgr0): It is expected that this script is run on a fresh install of Fedora Minimal."

read -p "$(tput setaf 6)Begin Hypr-Fedora Installation? (y/n): $(tput sgr0)" proceed

if [ "$proceed" != "y" ]; then
  echo "Installation aborted."
  exit 1
fi

# Make script executable and execute it
execute_script() {
  local script="$1"
  if [ -f "$script" ]; then
    chmod +x "$script"
    if [ -x "$script" ]; then
      "$script"
    else
      echo "Failed to make script '$script' executable."
    fi
  else
    echo "Script '$script' not found"
  fi
}

execute_script "system/copr.sh"
execute_script "system/fedora.sh"
execute_script "system/install_system.sh"
execute_script "system/flathub.sh"
execute_script "system/fonts.sh"
execute_script "system/pnpm.sh"

echo "$(tput setaf 2)[SUCCESS]: Installation complete$(tput sgr0)"
echo "It is recommended to reboot your pc."
exit 0
