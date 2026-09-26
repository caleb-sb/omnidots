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
  `firmware/efi/efivars` (4 attribute bytes, then 01 for enabled).
