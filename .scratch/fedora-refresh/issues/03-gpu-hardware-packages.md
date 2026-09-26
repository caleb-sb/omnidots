# 03 — GPU-dependent packages

**What to build:** The installer installs GPU drivers and video-acceleration packages only for the GPUs actually present, and handles NVIDIA properly on current drivers. The same scripts do the right thing on the desktop, on an Intel Core Ultra laptop, on a hybrid NVIDIA laptop and on an old Intel laptop.

See spec: Installer architecture (detection), Package sources (NVIDIA, Mesa), User Stories 21–29.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Detection classifies Intel GPUs as legacy or Broadwell-and-newer by device ID, and sets `HAS_HYBRID_GPU` when there is more than one GPU and one is integrated.
- [ ] Per-capability package lists exist for nvidia, amd-gpu, intel-gpu-modern and intel-gpu-legacy.
- [ ] NVIDIA: install the driver kmod, CUDA and the NVIDIA VA-API driver. Wait for the akmods build to finish before the reboot prompt. Warn and guide MOK enrollment when Secure Boot is enabled. Make no GRUB command-line edits.
- [ ] Mesa's VA drivers are swapped for the freeworld build when an AMD GPU or an Intel GPU (via Mesa) is present, and only then.
- [ ] Modern Intel gets `intel-media-driver`, legacy Intel gets the legacy Intel VA driver, and non-Intel machines get neither.
- [ ] Hybrid NVIDIA: NVIDIA runtime power management is enabled, and the plan records the integrated-GPU-first ordering that Hyprland will use (the Hyprland side is ticket 12).
- [ ] The old NVIDIA script is removed.
- [ ] Fixtures are added for the Core Ultra laptop, the hybrid Intel+NVIDIA laptop and the old Intel laptop, with bats assertions:
  - desktop: NVIDIA packages and freeworld, no Intel driver
  - Core Ultra: Intel media driver and freeworld, no NVIDIA
  - hybrid: NVIDIA packages plus runtime power management, iGPU first
  - old Intel: legacy driver
- [ ] Env overrides flip the relevant plan lines (tested for at least one flag).
- [ ] shellcheck passes.
