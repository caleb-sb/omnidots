# old-intel-laptop

Synthetic, not recorded: a Haswell ultrabook (ThinkPad T440/X240 class) with
Haswell-ULT HD Graphics 4400 (8086:0a16), which predates Broadwell and so
needs the legacy Intel VA driver. Its 8 Series chipset, I218-LM Ethernet,
Wireless 7260 and Realtek card reader make up the rest. No Secure Boot
variable, as on a legacy-BIOS install.

- `lspci.txt` is shaped like `lspci -n` output. Every vendor:device ID was
  checked against the PCI ID database (`/usr/share/hwdata/pci.ids`).
- `sysfs/` mirrors the relevant `/sys` entries under `bus/pci/devices`: the
  host bridge, the GPU and the Wi-Fi card.
