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
  crash-diagnostics.nix             # OPTIONAL — arms the hard-lockup detectors so the
                                    #   next freeze leaves evidence; portable
  gaming.nix                        # OPTIONAL — Steam/Proton + the 32-bit graphics and
                                    #   audio stack; portable (see "Gaming" below)
  disko-config.nix                  # declarative disk layout (edit device= before install)
  hardware-configuration.nix         # PLACEHOLDER — auto-generated during install, see below
  hardware-sys76.nix                # MACHINE-SPECIFIC — this computer only, see below
home/mps/home.nix                   # home-manager: fish, starship, git, dconf,
                                    #   hypridle/hyprlock (see "Idle, lock, suspend")
home/mps/dev-tools.nix              # OPTIONAL — CLI tooling (search, process/port
                                    #   inspection, direnv); portable, see "CLI tooling"
changelog/                          # ship notes, YYYY-MM-DD_NN.md — what changed and why
```

(Desktop dotfiles are **not** in this repo — see below.)

**The optional-import pattern.** `crash-diagnostics.nix` and `gaming.nix` are each
pulled in by exactly one line in `configuration.nix`'s `imports`, and nothing else
depends on either. Delete the line and that whole concern leaves the system — no
other edit, no orphaned settings. `hardware-sys76.nix` works the same way (see
"Moving this setup to a different computer"), with the one difference that it is
the only file here that is *not* portable.

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

## Gaming (Steam, Proton, GPU offload)

`hosts/hypr-nix/gaming.nix` — one import line in `configuration.nix`, nothing
else in the config depends on it. Delete the line and the desktop is exactly
what it was.

On Garuda this was `pacman -S steam` and it worked, because Arch's multilib
repo had already put a 32-bit graphics stack on the machine. NixOS asks for
that explicitly, and the failure when you don't is the classic one: **the Steam
client is a 32-bit program**, so without 32-bit Mesa/Vulkan it either refuses
to launch or opens to a black window, with no error that says so. Same story
for sound — a 32-bit game links against a 32-bit ALSA client library, and
without it the game runs, renders, and is silent.

What the file turns on:

| Setting | Why |
|---------|-----|
| `programs.steam.enable` | The **module**, not `pkgs.steam`. Steam needs an FHS sandbox wrapper, controller udev rules, and firewall holes that only the module wires up |
| `hardware.graphics.enable32Bit` | The 32-bit half of the graphics stack. Also pulls in the 32-bit NVIDIA userspace automatically |
| `services.pipewire.alsa.support32Bit` | 32-bit audio. Set here rather than in `configuration.nix` so it leaves with this file |
| `extraCompatPackages = [ proton-ge-bin ]` | GE-Proton in Steam's compatibility dropdown, versioned by nixpkgs instead of ProtonUp — same rollback story as the rest of the system |
| `protontricks`, `extest` | The registry-poke escape hatch, and the shim that makes Steam Input's controller remapping work on Wayland (it synthesizes X11 XTEST events, which don't exist here) |
| `gamemode`, `gamescope`, `mangohud` | Governor/priority boost on request, Valve's micro-compositor for resolution and upscaling, and the overlay that tells you which GPU is actually rendering |

**The 32-bit audio has a real cost**, restated here because it's easy to forget
why an unrelated update got slow: it drags i686 builds of the audio stack into
every nixpkgs bump, and Hydra's i686 coverage is thin enough that some of those
miss `cache.nixos.org` and compile on this machine.

`gamescope.capSysNice` is deliberately **off**, against what most guides say.
With native Steam the setcap'd binary refuses Steam's `LD_PRELOAD` environment
and the game dies with *"failed to inherit capabilities: Operation not
permitted"* ([NixOS/nixpkgs#351516](https://github.com/NixOS/nixpkgs/issues/351516)).
Normal scheduling priority beats not starting.

### The one thing you have to do per game (this machine)

`hardware-sys76.nix` runs the RTX 4070 in PRIME **offload** mode — the Intel
iGPU drives the panel and the NVIDIA card sleeps until something is explicitly
launched onto it. That's the right default for battery life and it's why
Hyprland is stable here, but it means:

> **A game launched normally from Steam renders on the Intel iGPU.** It runs,
> it runs badly, and nothing tells you why.

Per game, in Steam: **Properties → General → Launch Options**:

```
nvidia-offload %command%
```

`nvidia-offload` already exists on this system, from
`prime.offload.enableOffloadCmd` in `hardware-sys76.nix`. Composed with the
helpers above, a fully loaded launch option is:

```
nvidia-offload gamemoderun mangohud %command%
```

Confirm it worked: mangohud's overlay names the rendering GPU — it should say
NVIDIA, not Intel. Leave **Steam itself** on the iGPU; the client is a web
browser and has no business waking a 4070.

On a single-GPU machine none of this section applies and the rest of the file
still works unchanged.

## CLI tooling (`home/mps/dev-tools.nix`)

Follows the same optional-import pattern as `gaming.nix`: one line in
`home.nix`'s `imports`, nothing else depends on it, delete the line and the
whole concern leaves the system.

**Why it exists.** `home.nix` aliases `grep` to `ugrep --color=auto` — and
ugrep was not installed, so every interactive `grep` was a command-not-found.
That is the cheap version of a pattern worth naming: **a missing small CLI tool
rarely announces itself.** It surfaces as a script behaving oddly, or as nothing
at all while something downstream quietly does the wrong thing.

The expensive version: neither `lsof` nor `fuser` was installed. Nearly every
script that asks "which process holds this port" reaches for one of them. With
neither present the lookup returns nothing, the script carries on, and a dev
server that silently auto-increments past a busy port binds somewhere else —
so a harness serving several site builds side by side served the wrong ones
under the right labels, twice, before anyone suspected the missing binary.

**What is in it.**

| Group | Packages |
|---|---|
| Search | `ripgrep`, `ugrep` |
| Process / port | `lsof`, `psmisc` (fuser, killall, pstree) |
| Reflex tools | `sqlite`, `zip`, `dnsutils` (dig), `xxd`, `file`, `entr`, `just` |
| Git and shell | `delta` (+ git integration), `aha`, `duf`, `yq` |
| Shell environment | `direnv`, `nix-direnv` |

`ripgrep` lives here rather than in `home.nix` so the two search tools sit
together. Use rg by default — it respects `.gitignore`, which matters in any
tree carrying `node_modules`. Reach for ugrep when the search is a question
rather than a pattern: boolean queries (`-%`), fuzzy matching (`-Z`), searching
inside archives and PDFs, and its TUI (`ug --query`).

**What is deliberately absent.** `sd`, `dust`, `procs`, `difft`, `tokei`,
`hyperfine`, `jless`, `gron`, `mlr`, `httpie` and similar all duplicate
something already installed. The restraint is the point — a tools list earns
its place by being reached for, not by being comprehensive. `gcc` and `make`
are also absent, which does break `node-gyp` native builds; that is left alone
because a C toolchain in a user profile is a bigger decision than a CLI
utility, and the idiomatic NixOS answer is a per-project devshell.

The whole set is roughly 41 MB, all prebuilt from `cache.nixos.org` — the
switch that adds it looks like it does nothing, because there is nothing to
compile and nothing to fetch. New tools appear on `PATH` in a *new* shell;
the one you ran `upd` from keeps its old environment.

**direnv is here rather than in a devshell** because it must already be on
`PATH` when you `cd` into a directory, or it can never auto-load anything —
shipping it inside the shell it is meant to launch is circular. With it
installed, a project's `.envrc` can `use flake .#<shell>` and hand you that
project's toolchain on entry with nothing typed.

## Moving this setup to a different computer

Anything specific to *this* machine ("sys76" — a System76 Serval WS) is
quarantined in **`hosts/hypr-nix/hardware-sys76.nix`**: NVIDIA/Intel hybrid
graphics, System76 vendor support, Raptor Lake microcode, VA-API. It is pulled
in by exactly one line in `configuration.nix`'s `imports`.

To reuse this config on new hardware, delete that one line. Everything else —
Hyprland, waybar, pipewire, fonts, fish, the whole desktop — is hardware-generic
and keeps working, because `hardware.graphics.enable` plus mesa/nouveau gets you
a desktop on any GPU vendor. Then write a `hardware-<name>.nix` for the new
machine and import that instead. One file per machine; don't merge machine
details back into `configuration.nix`.

`crash-diagnostics.nix` and `gaming.nix` come along unchanged — both are
portable, and both are one import line each if the new machine doesn't want
them. The only machine-dependent thing in `gaming.nix` is *documented* rather
than configured: the PRIME-offload launch-option note, which simply doesn't
apply on a single-GPU box.

> **Nix gotcha:** flakes only see files that git tracks. A newly created `.nix`
> file fails to evaluate with *"Path ... is not tracked by Git"* until you
> `git add` it — staging is enough, no commit needed.

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

## Changelog

`changelog/` holds ship notes as `YYYY-MM-DD_NN.md` — what changed, why it
mattered, and what it cost. Commit messages in this repo already carry the
reasoning; the changelog is the version of that a person can read start to
finish without `git log`. Written when a coherent chunk of work lands, not
per commit.

## Not yet ported (low priority, port if you miss them)

Kvantum "Sweet" Qt theme, qt5ct/qt6ct fine-tuning, per-app 4K scaling
`.desktop` overrides (Warp 0.9x / Obsidian 1.5x — see
`garuda-hyprland-config/CLAUDE.md` for the exact values), swaync (mako is
wired up instead, matching what was actually `exec-once` in the live config).
