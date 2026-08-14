# hypr-nix

NixOS + Hyprland system config, successor to `garuda-hyprland-config`
(Garuda Linux). Ported: monitor layout, keybinds, waybar, wofi, mako,
fish/starship. Dropped: Garuda-only tooling (snapper-tools, garuda-welcome,
calamares, garuda-*-manager) — NixOS generations + rollback replace the job
snapper was doing.

## Repo layout

```
flake.nix                          # inputs: nixpkgs 26.05, home-manager, disko
hosts/hypr-nix/
  configuration.nix                 # system-level config (boot, users, hyprland, etc.)
  disko-config.nix                  # declarative disk layout (edit device= before install)
  hardware-configuration.nix         # PLACEHOLDER — auto-generated during install, see below
home/mps/home.nix                   # home-manager: fish, starship, git, dconf,
                                    #   hypridle/hyprlock (see "Idle, lock, suspend")
dotfiles/                           # live desktop config — hand-placed, NOT home-manager (see below)
  hypr/hyprland.conf                # Hyprland: monitors, keybinds, autostart
  hypr/scripts/                     # screenshot, idle-inhibitor, lock helpers
  waybar/config.jsonc               # bar layout + modules
  waybar/style.css                  # Nord theme
  waybar/scripts/                   # network_traffic (live throughput) etc.
  wpaperd/config.toml               # wallpaper daemon
  ghostty/config                    # terminal (carbonfox, blur, Menlo)
  wofi/style.css                    # launcher theme
```

## Desktop config lives in `dotfiles/` — hand-placed, not home-manager

The Hyprland/waybar/etc. configs in `dotfiles/` are **plain files copied to
`~/.config/`**, not managed by home-manager. Home-manager's Lua backend
miscompiled the Hyprland config, and a full `nixos-rebuild switch` would also
clobber working GTK/Qt theming — so these stay as hand-placed files. `dotfiles/`
is the source of truth; deploy by copying (e.g. `cp -r dotfiles/hypr ~/.config/`).

**Waybar** (`dotfiles/waybar/`) is the ported Garuda bar: workspaces, live
network throughput (center), CPU/RAM (→htop on click), battery, a rich
pulseaudio module (scroll=volume, click=alsamixer, right-click=pavucontrol),
network, tray, a calendar with today highlighted (scroll=change month,
right-click=year view), and an nwgbar power button. Icons are Material Design /
FontAwesome glyphs from a Nerd Font.

### Two NixOS gotchas that bit us (keep in mind)

- **Shebangs:** NixOS has **no `/bin/bash`** (only `/bin/sh`). Any script with
  `#!/bin/bash` silently fails to launch (this broke the waybar network module
  and affects the Garuda-era `hypr/scripts/`). Use `#!/usr/bin/env bash`.
- **Monitor name:** this panel is `eDP-1` (not Garuda's `eDP-2`), scaled `1.33`.
  Wrong name = the `monitor=` line is ignored and you get default 2x scale.
- **Waybar package vs. module:** `programs.waybar` is deliberately disabled in
  `home/mps/home.nix` (it wrote a stale `~/.config/waybar/config` that shadowed
  the hand-placed bar). Disabling the module also stops it installing the
  *package*, so `waybar` is declared explicitly in `configuration.nix`'s
  `systemPackages`. Remove that and the bar silently stops launching.

## Idle, lock, and suspend

Unlike the rest of the desktop config, **hypridle/hyprlock *are* home-manager
managed** (`services.hypridle` in `home/mps/home.nix`) — `~/.config/hypr/hypridle.conf`
is a read-only symlink into the Nix store, so editing it by hand does nothing.
Change the timeouts in `home.nix` and rebuild.

The cascade, in order:

| Idle | Action | Password on return? |
|------|--------|---------------------|
| 2.5 min (150s) | dim screen, keyboard backlight off | no |
| 5.5 min (330s) | display off (DPMS) | no |
| **15 min (900s)** | **lock session** | **yes** |
| 30 min (1800s) | suspend | yes |

This is a stationary home desktop, so the lock is deliberately relaxed to 15
minutes. Note the 30-minute suspend runs `before_sleep_cmd = loginctl
lock-session`, so **30 minutes is the effective ceiling** — idle past that and
you get a password prompt regardless of the lock timeout. Raise both if you
want longer.

### Assets NOT in this repo (sourced from the Nix store, keep them local)

- **Wallpaper:** `~/Pictures/Wallpapers/MilkyWay.png`, copied out of
  `pkgs.plasma-workspace-wallpapers` (so GC can't delete it). `wpaperd`
  points at it; swap the `path` in `wpaperd/config.toml` to change.
- **Nerd Font:** `~/.local/share/fonts/SymbolsNerdFontMono-Regular.ttf`, copied
  from kitty's bundled fonts, then `fc-cache -f`. Needed or all bar icons are
  tofu boxes. (Cleaner long-term: add `pkgs.nerd-fonts.symbols-only` to
  `fonts.packages` in `configuration.nix`.)

## About `hardware-configuration.nix`

You do **not** need to know your hardware specs ahead of time. That file is a
placeholder — `nixos-generate-config` overwrites it during install by
scanning the *actual* machine (disk controllers, CPU, kernel modules it
needs). The only thing you must know yourself is which block device is your
disk (`lsblk`, one command, obvious from size) — that goes in
`disko-config.nix`, not `hardware-configuration.nix`.

## Install runbook

### 1. Build the USB installer (from this Mac)

```bash
curl -L -o ~/Downloads/nixos.iso \
  https://channels.nixos.org/nixos-26.05/latest-nixos-graphical-x86_64-linux.iso
diskutil list                      # identify the USB stick, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=~/Downloads/nixos.iso of=/dev/rdisk4 bs=4m status=progress
```
(Use the *raw* disk device — `/dev/rdisk4`, not `/dev/disk4` — it's much
faster on macOS.)

### 2. Boot the target machine from the USB, then:

The live USB *is* the detection environment — you don't need to know
anything about this machine's hardware beforehand. Everything below runs
inside the booted live session, before the broken Garuda install is ever
touched.

```bash
# connect wifi if needed
nmtui

# identify hardware while you're here (informational only — configuration.nix
# already works generically on any result; see the Graphics comment there)
lspci -k | grep -A2 -E "(VGA|3D)"

# clone this config (or copy it via a second USB if offline)
git clone https://github.com/<you>/nixos-hypr-config.git
cd nixos-hypr-config

# find your disk name
lsblk
# edit hosts/hypr-nix/disko-config.nix -> disk.main.device to match

# partition, format, mount — DESTROYS the disk
sudo nix --experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- \
  --mode destroy,format,mount ./hosts/hypr-nix/disko-config.nix

# generate the REAL hardware-configuration.nix from the live scan
sudo nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/hypr-nix/hardware-configuration.nix

# install
sudo nixos-install --flake .#hypr-nix
reboot
```

### 3. After first boot

- Set your git identity for real in `home/mps/home.nix` (`programs.git.userName`/`userEmail`).
- Set `time.timeZone` in `configuration.nix` (currently `America/Chicago`).
- Uncomment the GPU driver block in `configuration.nix` matching your hardware
  (`lspci -k | grep -A2 -E "(VGA|3D)"` tells you which).
- Bring over LazyVim / Helix configs from `garuda-hyprland-config` directly
  (see the comment in `home/mps/home.nix`) rather than re-authoring them in Nix.
- To apply future changes: `sudo nixos-rebuild switch --flake ~/code/nixos-hypr-config#hypr-nix`
  (aliased to `upd` in fish).
- To roll back a bad update: `sudo nixos-rebuild switch --rollback`, or select
  an older generation from the systemd-boot menu at boot — this is the actual
  fix for the "didn't update often enough and it broke" problem: every switch
  is a new, independently bootable generation, not an in-place mutation.

## Keeping it up to date

```bash
cd ~/code/nixos-hypr-config
nix flake update                    # bump all inputs in flake.lock
# or bump just one:  nix flake update nixpkgs

# validate before committing to a switch (no sudo, builds into the store)
nix build --no-link .#nixosConfigurations.hypr-nix.config.system.build.toplevel

sudo nixos-rebuild switch --flake .#hypr-nix
```

Check what you're actually running vs. what's built:

```bash
nixos-rebuild list-generations | head        # is the newest one Current?
readlink -f /run/booted-system               # equal to /run/current-system?
```

If `booted` and `current` differ, the switch landed but the running kernel is
still the old one — reboot to pick it up. Committing `flake.lock` is what makes
a generation reproducible; a stray `result` symlink in the repo root is a
leftover GC root from `nix build` and is safe to delete.

## Not yet ported (low priority, port if you miss them)

Kvantum "Sweet" Qt theme, qt5ct/qt6ct fine-tuning, per-app 4K scaling
`.desktop` overrides (Warp 0.9x / Obsidian 1.5x — see
`garuda-hyprland-config/CLAUDE.md` for the exact values), swaync (mako is
wired up instead, matching what was actually `exec-once` in the live config).
