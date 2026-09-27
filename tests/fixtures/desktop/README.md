# desktop

The main desktop: NVIDIA RTX 3060 Ti (10de:24c9) plus the AMD Cezanne iGPU
(1002:1638). No battery, no backlight, one Bluetooth adapter. The Intel
devices in `lspci.txt` are the NVMe drive and Wi-Fi card, not GPUs.

- `lspci.txt` is verbatim `lspci -n` output.
- `sysfs/` mirrors the relevant `/sys` entries: the display devices, a host
  bridge and the Intel Wi-Fi card under `bus/pci/devices`, plus `class/`
  (placeholder files stand in for the real device directories).
- `class/power_supply` is synthetic: the desktop has no power supplies, but
  a wireless mouse's battery (type Battery, scope Device) and a USB-C port
  (type USB) are added to prove neither counts as a battery.
- `sysfs/bus/usb/devices` is synthetic: the root hubs (1d6b), a Logitech
  Unifying receiver (046d) and the Intel AX210 Bluetooth adapter (8087), so no
  fingerprint reader. Only `idVendor` and `idProduct` are mirrored; IDs were
  checked against the USB ID database (`/usr/share/hwdata/usb.ids`).
