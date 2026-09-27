# core-ultra-laptop

Synthetic, not recorded: a Meteor Lake laptop (Core Ultra 7 155H class) with
the Intel Arc iGPU (8086:7d55) as its only GPU, and a Samsung PM9A1 NVMe drive
(144d:a80a). The other Intel devices are the Meteor Lake platform's USB,
Wi-Fi, NPU, audio and bus controllers, not GPUs.

- `lspci.txt` is shaped like `lspci -n` output. Every vendor:device ID was
  checked against the PCI ID database (`/usr/share/hwdata/pci.ids`); the slot
  layout follows the usual Intel mobile layout (iGPU at 00:02.0).
- `sysfs/` mirrors the relevant `/sys` entries under `bus/pci/devices`: the
  host bridge, the GPU and the Wi-Fi card. Under `class/` it has a battery
  (`BAT0`), an AC adapter, the `intel_backlight` backlight and a Bluetooth
  adapter (placeholder files stand in for device directories).
- `sysfs/bus/usb/devices` has a Goodix fingerprint reader (27c6:538c), plus
  ordinary USB devices that don't count: the xHCI root hubs (1d6b), a Chicony
  camera (04f2, one off Elan's 04f3), the Intel AX211 Bluetooth adapter (8087)
  and the reader's interface entry `3-3:1.0`, which has no `idVendor`. Only `idVendor` and `idProduct` are mirrored; IDs
  were checked against the USB ID database (`/usr/share/hwdata/usb.ids`).
