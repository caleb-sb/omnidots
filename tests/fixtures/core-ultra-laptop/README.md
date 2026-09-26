# core-ultra-laptop

Synthetic, not recorded: a Meteor Lake laptop (Core Ultra 7 155H class) with
the Intel Arc iGPU (8086:7d55) as its only GPU, and a Samsung PM9A1 NVMe drive
(144d:a80a). The other Intel devices are the Meteor Lake platform's USB,
Wi-Fi, NPU, audio and bus controllers, not GPUs.

- `lspci.txt` is shaped like `lspci -n` output. Every vendor:device ID was
  checked against the PCI ID database (`/usr/share/hwdata/pci.ids`); the slot
  layout follows the usual Intel mobile layout (iGPU at 00:02.0).
- `sysfs/` mirrors the relevant `/sys` entries under `bus/pci/devices`: the
  host bridge, the GPU and the Wi-Fi card.
