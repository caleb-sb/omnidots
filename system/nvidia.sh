#!/usr/bin/env bash

nvidia_pkg=(
  akmod-nvidia
  xorg-x11-drv-nvidia-cuda
  libva
  libva-nvidia-driver
)

# Function for installing packages
install_package() {
  # Checking if package is already installed
  if sudo dnf list installed "$1" &>>/dev/null; then
    echo -e "$1 is already installed. Skipping..."
  else
    # Package not installed
    echo -e "Installing $1 ..."
    sudo dnf install -y "$1" 2>&1
    # Making sure package is installed
    if sudo dnf list installed "$1" &>>/dev/null; then
      echo -e "$1 was installed."
    else
      # Something is missing, exiting to review log
      echo -e "$1 failed to install :( , please check the install.log. You may need to install manually! Sorry I have tried :("
      exit 1
    fi
  fi
}

# Actual loops for installations
for PKG1 in "${nvidia_pkg[@]}"; do
  install_package "$PKG1" 2>&1
  if [ $? -ne 0 ]; then
    echo -e "$PKG1 Package installation failed, Please check the installation logs"
    exit 1
  fi
done

additional_options="rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia-drm.modeset=1 nvidia_drm.fbdev=1"

# Check if additional options are already present in GRUB_CMDLINE_LINUX
if grep -q "GRUB_CMDLINE_LINUX.*$additional_options" /etc/default/grub; then
  echo "GRUB_CMDLINE_LINUX already contains the additional options" 2>&1
else
  # Append the additional options to GRUB_CMDLINE_LINUX
  sudo sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"$additional_options /" /etc/default/grub
  echo "Added the additional options to GRUB_CMDLINE_LINUX" 2>&1
fi

# Update GRUB configuration
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
