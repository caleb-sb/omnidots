#!/usr/bin/env bash

terminal=(
  bat
  fish
  fzf
  kitty
  less
  nano
  neovim
  starship
  tree
)

bluetooth=(
  blueman
  bluez
  bluez-tools
)

utils=(
  brightnessctl
  cliphist # clipboard history
  curl
  dunst # notifications
  gawk
  grim # screenshots
  ImageMagick
  inxi # cpu, battery info
  gvfs # something about virtual mounts (idk)
  gvfs-mtp
  jq     #json parsing (waybar i think)
  kanshi # monitor management
  kvantum
  network-manager-applet
  openssl
  parallel
  qt5ct
  qt6ct
  qt6-qtsvg
  ripgrep
  slurp  # select region in wayland (screenshots)
  swappy # screenshot editing
  unzip
  usbutils #usb things
  waybar
  wget2
  wl-clipboard
  wlogout
  wofi
  xdg-user-dirs
  xdg-utils
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  xhost # polkit-gnome -> gparted wont work otherwise
  yad   # dialogs from scripts
)

hypr=(
  hyprland
  hyprlock
  hyprcursor
  hyprpolkitagent
  hyprpaper
  hyprland-qtutils
)

dev=(
  cargo
  golang
  lazygit
  python3
)

thunar=(
  Thunar
  ffmpegthumbnailer
  thunar-volman
  tumbler
  thunar-archive-plugin
  file-roller
)

audio=(
  pamixer
  pavucontrol
  pipewire-alsa
  pipewire-utils
)

apps=(
  brave-browser
  firefox
  inkscape
  meld
  obs-studio
  podman
  vlc
)

gaming=(
  steam
  discord
)

# Function for installing packages
install_package() {
  # Checking if package is already installed
  if sudo dnf list --installed "$1" &>>/dev/null; then
    echo -e "$1 is already installed. Skipping..."
  else
    # Package not installed
    echo -e "Installing $1 ..."
    sudo dnf install -y "$1" 2>&1
    # Making sure package is installed
    if sudo dnf list --installed "$1" &>>/dev/null; then
      echo -e "$1 was installed."
    else
      # Something is missing, exiting to review log
      echo -e "$1 failed to install :( , please check the install.log. You may need to install manually! Sorry I have tried :("
      exit 1
    fi
  fi
}

# Copy configurations
mkdir -p ~/.config
ln -s ~/omnidots/config/* ~/.config

# Actual loops for installations
for PKG1 in "${utils[@]}" "${terminal[@]}" "${bluetooth[@]}" "${hypr[@]}" "${fonts[@]}" "${dev[@]}" "${thunar[@]}" "${audio[@]}" "${apps[@]}" "${gaming[@]}"; do
  install_package "$PKG1" 2>&1
  if [ $? -ne 0 ]; then
    echo -e "$PKG1 Package installation failed, Please check the installation logs"
    exit 1
  fi
done
