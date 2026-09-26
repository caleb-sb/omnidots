# desktop

The main desktop: NVIDIA RTX 3060 Ti (10de:24c9) plus the AMD Cezanne iGPU
(1002:1638). No battery, no backlight, one Bluetooth adapter. The Intel
devices in `lspci.txt` are the NVMe drive and Wi-Fi card, not GPUs.

- `lspci.txt` is verbatim `lspci -n` output.
- `sysfs/` mirrors the relevant `/sys` entries: the display devices, a host
  bridge and the Intel Wi-Fi card under `bus/pci/devices`, plus `class/`
  (placeholder files stand in for the real device directories).
