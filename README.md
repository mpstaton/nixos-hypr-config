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
```

(Desktop dotfiles are **not** in this repo — see below.)

## Desktop config lives in a separate repo: `nix-hypr-dotfiles`

The Hyprland/waybar/wofi/wpaperd/ghostty configs are **not** managed by
home-manager and **not** stored here. They live in their own GNU Stow repo:

```
https://github.com/mpstaton/nix-hypr-dotfiles   ->   ~/nix-hypr-dotfiles
```

Why not home-manager: its Lua backend miscompiled the Hyprland config, and
`programs.waybar` wrote a stale `~/.config/waybar/config` that shadowed the
real bar. Why a separate repo: these change far more often than the system
config, and Stow symlinks them into place without a rebuild.

Deploy with `stow` from inside that repo (`stow hypr waybar wofi wpaperd
ghostty`), which symlinks e.g. `~/.config/hypr -> ~/nix-hypr-dotfiles/hypr/.config/hypr`.
Edit the files in `~/.config/` directly — you are editing the repo through the
symlink — then commit and push there, not here.

> This repo used to carry a duplicate `dotfiles/` copy. It was deleted once the
> Stow repo took over; the two had already drifted (the stale copy was missing
> the `Super+Shift+M` master-layout fix and the JetBrainsMono/ghostty change).
> **One copy, one remote.** Don't reintroduce it.

**The one exception:** `hypridle`/`hyprlock` *are* home-manager managed, from
`home/mps/home.nix` in this repo. See "Idle, lock, and suspend" below.

**Waybar** is the ported Garuda bar: workspaces, live
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

### Fonts — declarative, nothing to hand-place

Both Nerd Fonts the desktop needs come from `fonts.packages` in
`configuration.nix` and are installed by a rebuild. Nothing goes in
`~/.local/share/fonts/`, and no `fc-cache` step is needed:

| Package | Provides | Used by |
|---------|----------|---------|
| `nerd-fonts.symbols-only` | `Symbols Nerd Font Mono` | waybar `style.css` — icons are tofu boxes without it |
| `nerd-fonts.jetbrains-mono` | `JetBrainsMono Nerd Font` | ghostty `font-family` |

Earlier this repo told you to copy `SymbolsNerdFontMono-Regular.ttf` out of
kitty's bundle into `~/.local/share/fonts/`. That was superseded — the manual
copy was byte-identical to the store's and was deleted 2026-08-14. Two copies
of one family is a fontconfig ambiguity, and a hand-placed font is one more
thing a fresh clone silently won't restore. Verify with
`fc-match "Symbols Nerd Font Mono"`.

### Assets NOT in this repo (sourced from the Nix store, keep them local)

- **Wallpaper:** `~/Pictures/Wallpapers/MilkyWay.png`, copied out of
  `pkgs.plasma-workspace-wallpapers` (so GC can't delete it). `wpaperd`
  points at it; swap the `path` in `wpaperd/config.toml` to change. This is
  the **last** hand-placed asset — a fresh clone will not restore it, and
  `wpaperd` silently shows nothing if the path is missing.

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
