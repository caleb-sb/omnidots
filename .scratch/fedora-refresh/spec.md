# Fedora refresh: hardware-aware installer and desktop update

Status: ready-for-agent

## Problem Statement

I use this repo to turn a fresh Fedora Minimal install into my Hyprland desktop. It has drifted from the machine it was built for, and it can't safely target the laptops I also want to use it on.

- **The installer is stale.**
  - It enables an abandoned Hyprland COPR (solopasha) and a COPR for a package I don't install (swaync).
  - It pins a 2024 Nerd Fonts release.
  - It installs Postman through snap, which is never installed.
  - It installs packages I've replaced (dunst, waybar-era tooling, wofi, kanshi, Podman, Firefox).
- **It misses things I actually use:** Proton VPN, Proton Mail, Cura, Spotify, Claude Code, OpenWhispr, rustup, Docker, Heroic, Android Studio and playerctl.
- **Its community sources lag badly.** The starship and lazygit COPRs are months, or many releases, behind upstream.
- **It isn't hardware-aware.**
  - The NVIDIA script runs unconditionally, including GRUB edits that current drivers no longer need.
  - Laptop-only tools are installed everywhere.
  - Nothing adapts to a different CPU, GPU, battery, backlight or fingerprint reader.
  - I have a desktop (NVIDIA plus an AMD iGPU) and several laptops with different CPUs and GPUs. One set of scripts has to do the right thing on all of them without installing packages that are dead on arrival.
- **It isn't safely re-runnable.**
  - It installs one package per dnf call.
  - Its symlink step fails if a target already exists.
  - Everything that doesn't come from a dnf repo has no update path.
- **The config has rotted too:**
  - The lid switch calls a `swaylock` that isn't installed.
  - The clipboard bind kills `rofi` while I use wofi.
  - Polkit window rules target KDE's agent while I run hyprpolkitagent.
  - The volume and brightness scripts send dunst-style notifications even though qs-bar is now my notification daemon.
  - The monitor is hard-coded to DP-2.
  - fish config is home-manager output with my home path hard-coded.
  - Theming is split across five palettes and ~180MB of vendored icon and cursor themes.
- **Laptop gaps:** no low-battery warnings, no idle lock, and no way to make an external monitor primary when I dock.
- **No graphical login.** I boot to a TTY.

## Solution

A restructured, hardware-aware installer, plus a pass over the desktop config.

- **Install flow:**
  - Detects the machine's hardware capabilities and shows them to me to confirm.
  - Installs a core set that every machine gets, and only the extra packages the detected hardware can use.
  - Offers exactly two optional modules: gaming and Android development.
- **Plan preview:** the installer can print its whole plan without changing anything, and that plan is tested against recorded snapshots of real machines.
- **Re-runnable:** re-running it is safe.
- **Updates outside dnf:** a separate update command refreshes everything that doesn't come from a dnf repo.
- **Migrating this desktop:** a one-off migration command brings the existing desktop in line with what a fresh install would produce.
- **Desktop:**
  - Uses one palette, Tokyo Night Night, everywhere.
  - Reads the hardware it's running on at runtime rather than assuming it.
  - Gains:
    - on-screen popups for volume and brightness keys
    - battery warnings and a battery saver that also sets the CPU profile
    - an idle lock
    - automatic external-monitor handling on laptops
    - a Spotify media pill in the bar
    - a themed graphical login screen, with fingerprint unlock everywhere after login

## User Stories

### Installing

1. As the owner of several machines, I want one installer that works on my desktop and all my laptops, so that I maintain a single set of scripts.
2. As an installer user, I want the installer to detect my hardware capabilities rather than ask whether this is a desktop or a laptop, so that laptops with different CPUs and GPUs are each handled correctly.
3. As an installer user, I want to see the detected hardware flags and confirm them before anything is installed, so that a misdetection never silently installs the wrong drivers.
4. As an installer user, I want to override any detected flag with an environment variable, so that I can correct a wrong detection or force a module.
5. As an installer user, I want the installer to refuse to run as root, so that user-level files are never created as root.
6. As an installer user, I want to be asked once, up front, whether to include the gaming module and the Android module, so that the rest of the run needs no attention.
7. As an installer user, I want packages installed in batched dnf transactions per list, so that installs are fast and dependency resolution happens once.
8. As an installer user, I want the installer to be safe to re-run on a machine that is already set up, so that I can use it to repair or complete an install.
9. As an installer user, I want a dry-run mode that prints the full plan without changing anything, so that I can see exactly what a run would do on this machine. The plan covers hardware flags, repos, packages, flatpaks, downloads and system changes.
10. As an installer user, I want the installer to assume a Fedora Everything netinstall with the Minimal Install selection, so that the base system is predictable.
11. As an installer user, I want dnf configured with 10 parallel downloads and default-yes, and without the fastestmirror setting that dnf5 ignores, so that installs are quick and prompts behave predictably.
12. As an installer user, I want RPM Fusion free and nonfree enabled, so that codecs, Steam and NVIDIA drivers are available.
13. As an installer user, I want the only Hyprland COPR to be the one the Hyprland wiki names for Fedora (lionheartp/Hyprland), so that I follow the upstream-endorsed source.
14. As an installer user, I want the Quickshell COPR enabled, so that qs-bar and the greeter can run.
15. As an installer user, I want a clear summary at the end, including whether a reboot is required, so that I know the machine's state.

### Linking dotfiles

16. As a dotfiles user, I want each config directory symlinked into the XDG config dir by an idempotent step, so that re-running it never fails or duplicates links.
17. As a dotfiles user, I want an existing real file or directory at a link target backed up before it is replaced, so that I never lose local config.
18. As a dotfiles user, I want the link step runnable on its own, so that I can re-link on an existing machine without reinstalling anything.
19. As a dotfiles user, I want files that apps rewrite with machine state kept out of git, so that the repo doesn't churn. That covers fish's universal variables file and OpenWhispr's auto-generated binds file.
20. As a dotfiles user, I want an untracked per-machine override file for Hyprland, so that settings for one machine, such as a monitor mode or position, never leak onto others.

### Hardware capabilities

21. As an owner of an NVIDIA machine, I want the NVIDIA driver, CUDA and the NVIDIA VA-API driver installed only when an NVIDIA GPU is present, so that non-NVIDIA machines stay clean.
22. As an owner of an NVIDIA machine, I want the installer to wait until the kernel module has built before it tells me to reboot, so that the first boot doesn't come up without a driver.
23. As an owner of an NVIDIA machine with Secure Boot on, I want to be warned and walked through key (MOK) enrollment, so that the signed module loads.
24. As an owner of an NVIDIA machine, I want no hand edits to the GRUB command line, so that the setup relies on current driver defaults and survives kernel updates.
25. As an owner of an AMD GPU or an Intel GPU driven by Mesa, I want Fedora's Mesa VA drivers swapped for RPM Fusion's freeworld build, so that H.264 and HEVC hardware decode works in browsers, VLC and OBS.
26. As an owner of an Intel GPU from Broadwell onward (including Core Ultra), I want `intel-media-driver` installed, so that hardware video decode works.
27. As an owner of a pre-Broadwell Intel GPU, I want the legacy Intel VA driver instead, so that the right driver for that generation is used.
28. As a desktop owner with no Intel GPU, I want no Intel media driver installed, so that my machine isn't polluted with unusable packages.
29. As an owner of a hybrid-GPU laptop, I want Hyprland to render on the integrated GPU by default and NVIDIA runtime power management enabled, so that battery life isn't destroyed.
30. As a laptop owner, I want brightness tooling installed only when a backlight exists, so that the desktop doesn't get it.
31. As an owner of a machine with Bluetooth, I want BlueZ and blueman installed only when a Bluetooth adapter exists, so that machines without Bluetooth stay clean.
32. As an owner of a machine with a supported fingerprint reader, I want fprintd and its PAM module installed and enabled, so that I can authenticate with my finger.
33. As an owner of a machine without a fingerprint reader, I want no fingerprint packages installed, so that nothing dead is added.
34. As an owner of a machine with a fingerprint reader, I want an optional interactive enrollment step at the end of the install, so that the reader is usable immediately.
35. As a desktop owner with no battery, I want tuned set once to its throughput-performance profile, so that my CPU always runs at full performance without any UI.
36. As a laptop owner, I want tuned-ppd available, so that the bar can switch power profiles.

### Packages

37. As a user, I want Brave, Google Chrome, Inkscape, Meld, VLC, OBS Studio, Obsidian, Cura and Spotify on every machine, so that my everyday apps are always there.
38. As a Proton user, I want Proton VPN installed from Proton's official Fedora repository, so that it updates with the rest of the system.
39. As a Proton user, I want the installer to show Proton's key fingerprint and let dnf verify it, rather than hard-coding a fingerprint, so that the step keeps working across Fedora releases (the key differs per release).
40. As a Proton user, I want Proton Mail installed from Proton's official rpm, so that I use the vendor's build.
41. As a developer, I want pnpm (with Node via pnpm's own env command), bun, rustup, Go, Claude Code and Docker installed on every machine, so that every machine is a working dev box.
42. As a developer, I want Docker from Docker's official repository with the buildx and compose plugins, rootful, with me in the docker group, so that Docker behaves as its docs describe.
43. As a user, I want starship and lazygit installed from their upstream GitHub releases into my local bin directory, so that I'm not stuck on stale COPR builds.
44. As a user, I want OpenWhispr installed from its GitHub release rpm, so that I get the current version.
45. As a user, I want playerctl installed, so that my media keys work.
46. As a user, I want rofi as my launcher, so that I'm off unmaintained wofi, and so that the clipboard picker and launcher agree.
47. As a gamer, I want the optional gaming module to install Steam from RPM Fusion and Discord and Heroic from Flathub, so that my gaming setup is one choice away.
48. As an Android developer, I want the optional Android module to install Android Studio from the official tarball into /opt with a desktop entry, so that the paths my shell expects exist.
49. As a user, I want Podman, Firefox, Postman, snap, dunst, wofi, kanshi, ProtonUp-Qt, the swaync COPR, the atim COPRs and the Mullvad repo gone from the installer, so that nothing dead is installed.

### Updating things outside dnf

50. As a user, I want one update command that refreshes everything not delivered by a dnf repo, so that those tools don't rot. That covers starship, lazygit, OpenWhispr, Proton Mail, Android Studio, fonts, icon and cursor themes, and the GTK theme.
51. As a user, I want the update command to skip anything already at the latest version, so that it's quick and safe to run often.
52. As a user, I want the update command to only touch the Android Studio install if the Android module was installed, so that it doesn't install optional things behind my back.

### Migrating this desktop

53. As the owner of this existing desktop, I want a one-off migration command that removes the packages, repos and COPRs the refresh dropped, so that this machine ends up matching a fresh install.
54. As the owner of this existing desktop, I want the migration to show everything it will remove and ask before acting, so that nothing disappears unexpectedly.
55. As the owner of this existing desktop, I want the migration to remove GDM, dunst, wofi, kanshi, Podman, Firefox and ProtonUp-Qt, the dead COPRs, the Mullvad repo and the leftover Mullvad keyring entry, so that no leftovers remain.
56. As the owner of this existing desktop, I want the migration to have a dry-run mode as well, so that I can review it safely.

### Theme

57. As a user, I want Tokyo Night Night as the only palette, so that everything looks consistent. That covers kitty, tmux, Kvantum, qt6ct, rofi, hyprlock, Hyprland borders, qs-bar, the greeter, GTK and Neovim.
58. As a user, I want the Tokyonight GTK theme (Fausto-Korpsvart) installed at a pinned version with its libadwaita option, so that GTK3 and GTK4 apps match the palette.
59. As a user, I want Tela icons and Bibata cursors (including the hyprcursor variant) fetched at install time rather than stored in git, so that the repo sheds ~180MB of vendored assets.
60. As a user, I want the JetBrainsMono Nerd Font from its latest release, and the Material Symbols font qs-bar needs, installed and refreshable, so that fonts are current.
61. As a user, I want the unused Kvantum, qt5ct and kitty themes and the Andromeda GTK theme removed, so that the repo only carries what I use.
62. As a user, I want Qt apps to use qt6ct with Kvantum, and the environment variables for that set in the compositor environment, so that apps launched from Hyprland are themed, not just apps launched from a terminal.

### Shell

63. As a fish user, I want my config split into per-tool snippets that each check their tool exists before loading, so that a fresh machine without a tool doesn't error at startup.
64. As a fish user, I want paths added with fish's own path helper and my home directory never hard-coded, so that the config is portable and idiomatic.
65. As a fish user, I want abbreviations instead of aliases where appropriate, and the home-manager scaffolding removed, so that the config is idiomatic.

### Hyprland

66. As a Hyprland user, I want the config to detect NVIDIA at runtime before setting NVIDIA-only environment variables, so that the same config works on every machine.
67. As a laptop owner, I want the first connected external monitor to become primary automatically, so that docking needs no manual steps. Primary means workspaces, the bar, notification popups, cursor focus and the XWayland primary display.
68. As a laptop owner, I want the built-in panel placed below the external monitor while docked, and turned off when I close the lid while docked, so that the layout matches my desk.
69. As a laptop owner, I want the built-in panel back as the only, primary display when I undock, so that the laptop is usable immediately.
70. As a laptop owner, I want a keybind that forces the built-in panel back on, so that I can recover from Hyprland's known bug where the panel stays off after unplugging.
71. As a user with multiple external monitors, I want the primary picked by connector name in a predictable order, and overridable per machine, so that the choice is deterministic.
72. As a laptop owner, I want closing the lid while undocked to lock and suspend, so that the laptop doesn't drain in a bag.
73. As a desktop owner, I want nothing ever to suspend my machine, so that it matches how I use it.
74. As a user, I want the dead KDE polkit window rules replaced with float and opacity rules for hyprpolkitagent, so that auth prompts float.
75. As a user, I want the duplicated OpenWhispr binds file and the stale keybinding backup deleted, so that there is one source for each bind.
76. As a user, I want nm-applet no longer autostarted while blueman-applet keeps running as the Bluetooth pairing agent, so that I keep working pairing prompts without a redundant network applet.
77. As a user, I want the clipboard bind to target rofi correctly, so that it opens and closes as intended.

### qs-bar

78. As a user, I want volume keys to change volume and show a popup at the bottom centre of the screen, so that I get feedback when I press them.
79. As a user, I want brightness keys to change brightness and show the same kind of popup, so that I get feedback on laptops.
80. As a user, I want the popup to appear only when I use the keys, not when volume changes elsewhere, so that it isn't noisy.
81. As a user, I don't want a brightness item on the bar or a mic-mute or caps-lock popup, so that the bar stays minimal.
82. As a laptop owner, I want a notification at 20% battery and a critical notification at 10% when not charging, so that I'm never caught out.
83. As a laptop owner, I don't want the machine suspended automatically at low battery, so that I stay in control.
84. As a laptop owner, I want a battery-saver toggle in the power panel that switches the CPU to its power-saver profile, so that I can stretch battery life.
85. As a laptop owner, I want battery saver to switch on by itself at 20% when not charging and off when I plug in, with my manual choice taking precedence, so that it's automatic but overridable.
86. As a laptop owner, I want game mode to switch the CPU to performance and restore the previous profile when turned off, so that games get full power.
87. As a laptop owner, I want game mode and battery saver to be mutually exclusive, with balanced as the default, so that the profile is always predictable.
88. As a desktop owner, I want no power-profile controls shown, so that the UI stays minimal where they're pointless.
89. As a user, I want the screen locked with hyprlock after 10 minutes idle and the display off after 15 minutes, so that an unattended machine is secured. Idle inhibitors such as video playback are respected.
90. As a Spotify listener, I want a media pill on the left of the bar after the workspaces, showing the track title and artist with previous, play/pause and next buttons, so that I can control music without switching windows.
91. As a Spotify listener, I want the pill visible while Spotify is open with a track loaded, including when paused, and hidden when Spotify closes, so that it only takes space when useful.
92. As a Spotify listener, I want the track text truncated to about 30 characters with an ellipsis, and clicking it to focus the Spotify window, so that the pill stays compact and useful.
93. As a user, I want the pill to track only Spotify, not browser tabs or other players, so that it reflects my music.

### Login and authentication

94. As a user, I want a graphical login screen in the Tokyo Night style that matches qs-bar and hyprlock, so that boot looks like the rest of my desktop.
95. As a user, I want the login screen to fall back to a terminal greeter if the graphical one fails to load, so that a broken build can never lock me out.
96. As a user, I want to log in with my password, so that my keyring unlocks. The keyring holds the browser storage keys, Proton VPN session, gh token and OpenWhispr key.
97. As a user with a fingerprint reader, I want fingerprint to work in hyprlock alongside the password, and for sudo and polkit, so that I rarely type my password after login.
98. As a user, I want the system to boot to the graphical target with greetd enabled, so that I no longer start Hyprland from a TTY.

### Testability

99. As the maintainer, I want the installer's dry-run plan tested against recorded hardware snapshots of my real machine types, so that hardware gating regressions are caught without reinstalling.
100. As the maintainer, I want every shell script to pass shellcheck, so that common shell bugs are caught early.

## Implementation Decisions

### Installer architecture

- **Capability-based detection, not machine profiles.** There is no "desktop" or "laptop" input anywhere.
- **Detection module.** Produces these capability flags:

  | Flag | Detected from |
  |---|---|
  | `HAS_NVIDIA` | PCI display-class device with vendor 10de |
  | `HAS_AMD_GPU` | vendor 1002 |
  | `HAS_INTEL_GPU` | vendor 8086, plus a generation classification (legacy or Broadwell-and-newer) from the device ID |
  | `HAS_HYBRID_GPU` | more than one GPU, one of them integrated |
  | `HAS_BATTERY` | a BAT power-supply entry in sysfs |
  | `HAS_BACKLIGHT` | a backlight class entry |
  | `HAS_BLUETOOTH` | a bluetooth class entry |
  | `HAS_FPRINT` | a USB vendor matching a known libfprint vendor: Goodix, Synaptics, Elan, Validity, Egis, FocalTech |

  - Each flag can be overridden by an environment variable of the same name.
  - Detection reads the sysfs root and the `lspci` output through overridable inputs. This is the test seam.
- **Shared library.** Logging, a batched package install that takes a list, flatpak install, GitHub-release fetch (binary or rpm), and a helper that says whether a flag is set.
- **Plain-text package lists, one per module.** Core, gaming, android, and one per hardware capability (nvidia, amd-gpu, intel-gpu-modern, intel-gpu-legacy, battery, backlight, bluetooth, fprint). Comments are allowed. The installer composes the final set from the flags and the modules I choose.
- **Numbered module scripts, each doing one job:**
  - repos
  - core packages
  - hardware packages
  - flatpaks
  - fonts and theme assets
  - dev toolchains
  - Docker
  - NVIDIA post-steps
  - power profile
  - fingerprint
  - greeter
  - optional gaming
  - optional Android
- **Dry-run mode.** Every module takes part. Dry-run prints the actions it would take to stdout in a stable, line-oriented format that the tests assert on, and runs nothing.
- **Link step.** Idempotent and runnable on its own: it backs up an existing non-link target with a timestamp, then links it.
- **Update command.** Refreshes everything not from a dnf repo. It compares the installed version with the latest release and skips it when they match.
- **Migration command.** One-off: it removes dropped packages, repos, COPRs and the Mullvad keyring item. It prints its list, asks for confirmation, and supports dry-run.
- **Removed:** the JaKooLit credit header and the per-package install loop.

### Package sources

- **Hyprland:** lionheartp/Hyprland COPR, and no other Hyprland COPR is referenced.
- **Quickshell:** errornointernet/quickshell COPR.
- **Proton VPN:**
  - Install the release rpm from Proton's Fedora repository for the running Fedora version, then install `proton-vpn-gnome-desktop`.
  - Despite the name, that package only pulls the GTK app, the CLI, the daemon and the NetworkManager plugin.
  - The key fingerprint is displayed, not hard-coded.
- **Proton Mail:** the official rpm, installed via the update command's release-fetch path.
- **Proton Pass and Drive:** deferred until they ship a GUI rpm or a dnf repo.
- **Docker:** Docker CE repository; `docker-ce`, `docker-ce-cli`, `containerd.io`, and the buildx and compose plugins. The service is enabled and I'm added to the docker group.
- **starship, lazygit:** GitHub release binaries into the user's local bin directory.
- **OpenWhispr:** GitHub release rpm.
- **Claude Code:** its native installer.
- **Flathub:** Obsidian, Spotify and Cura in core; Discord and Heroic in gaming.
- **Node:** installed with pnpm's own env command.
- **NVIDIA:** `akmod-nvidia`, CUDA, and `libva-nvidia-driver`. Wait for the akmods build to finish, warn about Secure Boot and MOK, and make no GRUB edits.
- **Mesa:** swap to freeworld when an AMD GPU or an Intel GPU driven by Mesa is present.
- **Power profile:** without a battery, set tuned's throughput-performance profile once. With a battery, install tuned-ppd; the bar controls it.
- **Fingerprint:** install fprintd and fprintd-pam, enable authselect's fingerprint feature, and offer enrollment.
- **Greeter:** install and enable greetd and tuigreet, switch the default target to graphical, and ensure the greetd PAM stack includes the keyring module.

### Configuration

- Hyprland detects hardware at runtime (the NVIDIA env vars check the NVIDIA driver's proc entry).
- An optional, untracked per-machine override file is loaded last if present. The desktop's 3840x2160@144, scale 1.5 on DP-2 moves there.
- Monitor handling uses the Lua config's `monitor.added` and `monitor.removed` events:
  - With an external monitor connected, the external output sorted first by connector name is primary.
  - The built-in panel sits below it, or is disabled while the lid is closed.
  - Undocked, the built-in panel is primary at its preferred mode with automatic position and scale.
  - "Primary" moves workspaces 1–N, bar placement, notification popups, focus and the XWayland primary.
  - A keybind force-enables the built-in panel.
- The lid switch is handled by the same module:
  - Docked: turn the panel off or on.
  - Undocked on a machine with a battery: lock with hyprlock, then suspend.
  - No battery: nothing happens.
  - swaylock is removed everywhere.
- The media keys keep using playerctl.
- The volume and brightness keys call qs-bar's IPC. qs-bar performs the change and shows the popup. The volume and brightness control scripts are deleted, as is the battery-notify script.
- Environment variables GUI apps need move into Hyprland's environment: Qt platform theme (qt6ct), Kvantum style, EDITOR, XDG dirs.
- Autostart drops kanshi and nm-applet and keeps blueman-applet. The gsettings calls switch to the Tokyonight GTK theme, Tela icons and Bibata.
- The clipboard bind and script target rofi.
- The OpenWhispr binds file and fish's universal variables file are gitignored.

### qs-bar

- **Popup module:**
  - Exposes IPC targets for volume up, volume down, mute, brightness up and brightness down.
  - Each target performs the change itself: PipeWire for volume, brightnessctl for brightness.
  - Each shows a bottom-centre popup with an icon, a level bar and a percentage, which auto-hides.
  - Brightness targets are no-ops without a backlight.
- **Power:**
  - Uses Quickshell's PowerProfiles service, which tuned-ppd provides over the power-profiles-daemon D-Bus API.
  - The profile is derived from state: game mode on → performance; battery saver on → power-saver; neither → balanced. Turning one on turns the other off.
  - Battery saver auto-engages at 20% when discharging and disengages on AC. A manual toggle overrides the automatic behaviour until the next AC transition.
  - Power-profile behaviour and the saver toggle only exist when there's a laptop battery.
  - Existing game-mode behaviour (blur, animations, opacity, quiet notifications, zero-scaling) is kept.
- **Battery warnings:** `SysStats` sends a normal notification at 20% and a critical one at 10% while discharging, once per threshold per discharge cycle, with no auto-suspend.
- **Idle:**
  - The existing idle monitor in the power module is repurposed: lock at 10 minutes and display off at 15 minutes, with inhibitors respected.
  - Suspend-on-idle and the sleep-minutes setting are removed.
  - Display off and on go through Hyprland's DPMS dispatcher.
- **Media pill:**
  - A new module uses Quickshell's MPRIS service, filtered to the player whose identity or D-Bus name is Spotify.
  - It sits in the left group after the workspaces.
  - It's visible while Spotify has a track loaded, whether playing or paused.
  - Its text is "Title — Artist", elided at about 30 characters, with previous, play/pause and next buttons.
  - Clicking the text focuses the Spotify window via Hyprland.

### Greeter

- A new Quickshell config for the greeter uses Quickshell's greetd service and reuses qs-bar's theme and components (shared, not copied).
- It runs inside a minimal Hyprland session started by greetd.
- It supports the multi-step PAM conversation (info and secret prompts).
- It lists sessions, with Hyprland (via start-hyprland) as the default.
- The greetd config falls back to tuigreet if the Quickshell greeter exits abnormally.
- The greeter's PAM stack authenticates with the password only, so the keyring unlocks. Fingerprint is enabled for hyprlock (in parallel with the password), sudo and polkit through authselect.

### Theme

- One Tokyo Night Night palette file per consumer, all in the repo:
  - kitty
  - tmux
  - Kvantum
  - qt6ct
  - rofi
  - hyprlock
  - Hyprland borders
  - qs-bar theme (already Night; verify it)
  - Neovim through tokyonight.nvim with the night style
- The GTK theme is Fausto-Korpsvart's Tokyonight-GTK-Theme at a pinned commit.
  - Install it with its libadwaita option.
  - Pick the tweak closest to the Night palette.
  - It needs `sassc` and `gtk-murrine-engine`.
- Delete the vendored icons, cursors, hyprcursors and Andromeda theme, the other Kvantum and qt5ct themes, and the Gruvbox and Storm kitty themes. Tela, Bibata and hyprcursor Bibata are fetched at pinned versions.

### fish

- Per-tool snippets in fish's conf.d: env, pnpm, bun, cargo, android, kitty and starship. Each checks its tool or directory exists before loading.
- Use fish's path helper.
- `lg` becomes an abbreviation.
- The `start-hyprland` aliases are removed, since the greeter launches the session.
- The kitten-ssh abbreviation is kept.
- The home-manager scaffolding and the hard-coded home path are removed.

## Testing Decisions

- **Seam.** The installer's dry-run plan is the one automated test seam.
  - Tests run the full installer and the migration command in dry-run mode, against hardware fixtures supplied through the detection module's overridable sysfs root and `lspci` input.
  - Tests assert only on the printed plan (flags, repos, packages, flatpaks, downloads, system changes), never on internal functions or file layout.
- **Fixtures:**
  - this desktop: NVIDIA RTX 3060 Ti plus AMD Cezanne iGPU, no battery, no backlight
  - a laptop with an Intel Core Ultra GPU, a battery, a backlight, Bluetooth and a Goodix-class fingerprint reader
  - a hybrid laptop with an Intel iGPU plus an NVIDIA GPU, a battery and a backlight
  - an old Intel (pre-Broadwell) laptop with a battery and no fingerprint reader
- **Key assertions:**
  - The desktop never gets the Intel media driver, fprintd, brightnessctl or tuned-ppd. It does get the NVIDIA packages, freeworld, and the throughput-performance step.
  - The Core Ultra laptop gets the Intel media driver, fprintd with authselect, brightnessctl and tuned-ppd, and no NVIDIA packages.
  - The hybrid laptop gets the NVIDIA packages plus runtime power management, with the integrated GPU ordered first.
  - The old Intel laptop gets the legacy Intel VA driver and no fprintd.
  - Optional modules appear only when chosen.
  - Environment-variable overrides flip the relevant plan lines.
  - A migration dry-run lists exactly the dropped items.
- **Tooling.** Tests use bats. shellcheck must pass on every shell script. Both are dev-only and not installed on target machines.
- **Smoke checks for config tickets.**
  - The Lua config files parse with luajit.
  - fish files pass fish's syntax check.
  - qs-bar and the greeter config load under Quickshell without QML errors in the log, where a session is available.
- **Manual acceptance.** Everything else is verified manually, and only after all tickets are complete: I'll do a single real install on the desktop and on laptops. Tickets must not block on hand verification. The spec's user stories form the acceptance checklist for that run. That includes key presses, hotplug, lid, fingerprint, the greeter, battery saver and the media pill.
- **Prior art.** None; the repo has no tests yet. This work introduces the test directory and the fixtures.

## Out of Scope

- Proton Pass and Proton Drive, until they ship a GUI rpm or a dnf repo.
- The Proton Authenticator.
- GameMode (Feral).
- A brightness item on the bar, and mic-mute and caps-lock popups.
- Fingerprint at the login screen.
- Suspend on the desktop, and suspend-on-idle anywhere.
- Rewriting git history to purge the vendored assets. They are deleted going forward only.
- Themes other than Tokyo Night Night, and palette switching.
- qs-bar as the Bluetooth pairing agent (blueman-applet stays).
- Media controls for players other than Spotify.
- Seeking and album art in the media pill.
- Distros other than Fedora, and Fedora releases older than the one currently supported.
- Hand verification during implementation. It happens once, on real hardware, after all tickets are complete.

## Further Notes

- **Working branch:** `fedora-refresh`. The baseline commit snapshots the pre-refresh state, including the qs-bar migration.
- **Research behind these decisions** (September 2026):
  - The Hyprland wiki names lionheartp/Hyprland for Fedora; solopasha is abandoned.
  - The COPR builds lag upstream: atim/lazygit is at 0.47.2 with its last build in February 2025, while upstream is 0.65.1. atim/starship is at 1.24.2, while upstream is 1.26.0.
  - Proton VPN's official Fedora repo uses a release rpm whose signing key differs per Fedora release.
  - The Proton Mail and Proton Pass Flathub builds are community-packaged and unverified.
  - Proton Drive has only an official CLI; a GUI is promised for late 2026.
  - Kanshi has a history of fighting Hyprland over output state. Hyprland 0.55's Lua events make an external tool unnecessary.
  - There's an open Hyprland regression where the built-in panel stays off after unplugging an external monitor, which is why the force-enable keybind exists.
  - tuigreet with fprintd in PAM has a reported authentication bypass, so tuigreet is only a fallback and the greeter's PAM stack is password-only.
  - A fingerprint match cannot unlock gnome-keyring, which is why login uses the password.
- **Current state on this desktop:**
  - tuned-ppd is installed and the active profile is balanced, not performance.
  - GDM is installed but not enabled; the default target is multi-user.
  - OpenWhispr 1.8.3 is installed while upstream is at 1.10.2.
- OpenWhispr regenerates its binds file inside the linked Hyprland config directory, which is why that file is gitignored rather than just deleted.
