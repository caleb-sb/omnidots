# hybrid-laptop

Synthetic, not recorded: an Alder Lake-H laptop with the Iris Xe iGPU
(8086:46a6) and a muxless NVIDIA RTX 3050 Ti Mobile (10de:25a0), which shows
up as a 3D controller (class 0302) rather than a VGA controller. Secure Boot
is on.

- `lspci.txt` is shaped like `lspci -n` output. Every vendor:device ID was
  checked against the PCI ID database (`/usr/share/hwdata/pci.ids`); the slot
  layout follows the usual Intel mobile layout (iGPU at 00:02.0, the dGPU
  behind the CPU's x16 port on bus 01).
- `sysfs/` mirrors the relevant `/sys` entries: the host bridge and both GPUs
  under `bus/pci/devices`, and the `SecureBoot` EFI variable under
  `firmware/efi/efivars` (4 attribute bytes, then 01 for enabled). Under
  `class/` it has a battery (`BAT0`), an AC adapter, the `intel_backlight`
  backlight and a Bluetooth adapter (placeholder files stand in for device
  directories).
- `sysfs/bus/usb/devices` has the root hubs (1d6b), a Chicony camera (04f2,
  one off Elan's 04f3) and the Intel AX211 Bluetooth adapter (8087), so no
  fingerprint reader. `bus/hid/devices` has an Elan I2C touchpad
  (`0018:04F3:3140`), which isn't a USB device and doesn't count either. USB
  IDs were checked against the USB ID database (`/usr/share/hwdata/usb.ids`).
