---
title: "Migrate to the Dendritic Pattern"
lede: "Today this config is filed by where each setting goes — system or home. The dendritic pattern files it by what each feature is, so Hyprland, gaming, or the dev toolchain each live in exactly one file, whole."
date_created: 2026-10-01
date_modified: 2026-10-01
authors:
  - mps
augmented_with:
  - Claude Code on Claude Opus 5.5
semantic_version: 0.0.0.1
status: Draft
tags:
  - Plan
  - NixOS
  - Nix-Flakes
  - Flake-Parts
  - Dendritic-Pattern
  - Refactor
---

# Migrate to the Dendritic Pattern

## Why care?

A NixOS config with home-manager has two kinds of settings: those that
configure the **machine** (NixOS) and those that configure the **user**
(home-manager). This repo is filed along that line — `hosts/` for one, `home/`
for the other. That's the conventional layout, and it works.

The cost shows up when one *feature* needs both. Hyprland is a system service
(`programs.hyprland`, the portals, SDDM's default session) *and* a user setup
(hypridle, hyprlock, mako). Fish is enabled system-wide so it can be a login
shell, *and* configured in home-manager for aliases and init. To understand or
remove "Hyprland," you read two files in two directories and hope you found
every piece.

The **dendritic pattern** files the config by feature instead. Each file is one
aspect of the system and carries every class of config that aspect needs —
NixOS, home-manager, and later nix-darwin if a Mac appears. A machine is then
nothing more than a list of the features it has.

This document is a plan, not an implementation. Nothing here has been changed.

## What "dendritic" means, concretely

It is a convention, not a tool. Described by mightyiam
(<https://github.com/mightyiam/dendritic>); it rests on two pieces of
infrastructure:

- **[flake-parts](https://flake.parts)** — makes the flake itself a module
  system. Its `flakeModules.modules` provides the `flake.modules.<class>.<name>`
  option that the pattern publishes into. *(Verified present in flake-parts,
  2026-10-01.)*
- **[import-tree](https://github.com/vic/import-tree)** — imports every `.nix`
  file under a directory. *(Verified, last modified 2026-09-03.)*

Four rules follow:

1. **Every `.nix` file is a flake-parts module**, and all of them are loaded
   automatically. There are no `imports = [ ./foo.nix ]` lists to keep in sync;
   adding a file is enough to add it.
2. **Each file publishes named modules by class**:
   `flake.modules.nixos.<feature>`, `flake.modules.homeManager.<feature>`. One
   file may publish to several classes — that's the point.
3. **Hosts compose features.** A host's file is a list of feature names.
4. **No `specialArgs` / `extraSpecialArgs`.** Every file is a top-level
   flake-parts module and already sees `inputs` and the shared config; nothing
   is hand-threaded downward.

### A feature file

```nix
# modules/dev-tools.nix
{
  flake.modules.nixos.dev-tools = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [ unstable.pnpm unstable.uv python3 file ];
  };

  flake.modules.homeManager.dev-tools = { pkgs, ... }: {
    home.packages = with pkgs; [ ripgrep unstable.ugrep unstable.bun unstable.deno ];
    programs.direnv.enable = true;
  };
}
```

### A host file

```nix
# modules/hosts/hypr-nix.nix
{ inputs, config, ... }:
let m = config.flake.modules; in {
  flake.nixosConfigurations.hypr-nix = inputs.nixpkgs.lib.nixosSystem {
    modules = with m.nixos; [
      hypr-nix-hardware sys76 base unstable-overlay
      hyprland plasma gaming crash-diagnostics
      shell dev-tools user-mps
    ];
  };
}
```

### The whole of `outputs`

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; }
  (inputs.import-tree ./modules);
```

## Is it worth it here? (honest read)

**Moderately, today.** The pattern's headline benefit — features shared cleanly
across several hosts — doesn't apply to a repo with one machine and one user.

What it *does* buy right now:

- **One feature, one file.** The concrete splits listed below stop being split.
- **The `unstable` overlay stops leaning on `useGlobalPkgs`.** It's declared in
  `configuration.nix` today and consumed by three files; home-manager only sees
  it because `useGlobalPkgs = true`. As its own module it's explicit.
- **No `specialArgs`, no import lists.**

**It clearly pays** the day a second machine shows up — another NixOS box, a
server, or a Mac under nix-darwin. That host's file is a different list of the
same features, and anything that isn't shared simply isn't in its list.

## Where the current config is split across files

These are the features that live in both `hosts/` and `home/` today — the
concrete wins, and the best order to split in:

| Feature | System side (today) | Home side (today) |
|---|---|---|
| `unstable-overlay` | `nixpkgs.overlays` in `configuration.nix` | consumed in `home.nix`, `dev-tools.nix` |
| `dev-tools` | pnpm, uv, python3, file… in `configuration.nix` | `home/mps/dev-tools.nix` |
| `shell` | `programs.fish.enable`, `generateCompletions` | `programs.fish`, aliases, starship |
| `hyprland` | `programs.hyprland`, portals, SDDM default session | hypridle, hyprlock, mako |
| `plasma` | `services.desktopManager.plasma6` | `programs.plasma` (plasma-manager) |
| `user-mps` | `users.users.mps` | `home.username`, stateVersion, home-manager wiring in `flake.nix` |

Single-class files that just move: `hardware-configuration.nix` +
`disko-config.nix` (→ `hardware/hypr-nix.nix`), `hardware-sys76.nix`,
`gaming.nix`, `crash-diagnostics.nix`.

## Target layout

```
modules/
  flake-parts.nix          # imports flake-parts' `modules` flakeModule; sets systems
  hosts/hypr-nix.nix       # the feature list
  hardware/hypr-nix.nix    # hardware-configuration + disko
  hardware/sys76.nix       # PRIME offload, NVIDIA
  base.nix                 # boot, networking, locale, audio, bluetooth, firmware
  unstable-overlay.nix     # `pkgs.unstable`, stated once
  hyprland.nix             # system + home halves
  plasma.nix               # system + home halves
  gaming.nix
  crash-diagnostics.nix
  shell.nix                # fish (both halves), starship, aliases
  cli-tools.nix            # eza, zoxide, yazi, lazygit, atuin…
  dev-tools.nix            # system + home halves
  user-mps.nix             # account + home-manager wiring
```

Roughly 1,660 lines across 9 files today; expect a similar total across ~14
files, each smaller and single-purpose.

## The migration, step by step

Every step lands on a branch and is gated by the same check: **the new build
must produce no package difference from the old one.**

```bash
# before starting, on main:
nix build .#nixosConfigurations.hypr-nix.config.system.build.toplevel -o /tmp/before
# after each step, on the branch:
nix build .#nixosConfigurations.hypr-nix.config.system.build.toplevel -o /tmp/after
nvd diff /tmp/before /tmp/after   # expect: no version changes, no added/removed packages
```

(The top-level store path itself may still differ — `system.configurationRevision`
embeds the git rev. `nvd` comparing package sets is the meaningful test.)

1. **Add inputs.** `flake-parts` and `import-tree`, with
   `inputs.nixpkgs-lib.follows = "nixpkgs"` on flake-parts.
2. **Swap `outputs` to `mkFlake` + `import-tree ./modules`.** Create
   `modules/flake-parts.nix` importing `inputs.flake-parts.flakeModules.modules`
   and setting `systems = [ "x86_64-linux" ];`.
3. **Wrap, don't split.** Move each existing file into `modules/` with the
   minimum edit: its current body becomes the value of one
   `flake.modules.nixos.<name>` (or `.homeManager.<name>`). `configuration.nix`
   becomes `base` wholesale; `home.nix` becomes `homeManager.mps` wholesale.
   Write the host file. Replace `specialArgs` / `extraSpecialArgs` uses of
   `inputs` with the outer module's `inputs` (captured by closure).
   **Gate: `nvd diff` clean.** This is the riskiest step and changes nothing
   the machine runs.
4. **Switch to the branch build once**, live, and use it for a day. Merge.
5. **Split by feature, one commit each,** in the table's order —
   `unstable-overlay` first because everything else depends on it, then
   `dev-tools`, `shell`, `hyprland`, `plasma`, `user-mps`. **Gate each with
   `nvd diff`.**
6. **Update the README** layout section and write a changelog entry.

Every step is reversible with `git revert` and, if switched, the systemd-boot
menu.

## Risks & gotchas

- **Two `config`s in one file.** Inside a feature file, the outer
  `{ config, ... }:` is the *flake-parts* config; the inner
  `{ config, pkgs, ... }:` is the *NixOS/home-manager* config. Confusing them is
  the most common mistake. Name the outer one by what you take from it
  (`let hm = config.flake.modules.homeManager; in …`).
- **The overlay's infinite-recursion guard.** The comment in
  `configuration.nix` about reading the platform from `prev.stdenv` (not
  `final`, not module config) must survive the move verbatim.
- **`hunk` and its bun2nix build** take `inputs.hunk.packages.${system}` — keep
  using `pkgs.stdenv.hostPlatform.system`, not `pkgs.system`.
- **Live switches can take down the session.** The 2026-10-01 switch logged
  the Hyprland session out mid-activation. Step 3's whole point is that the
  switch it produces should be a no-op; still, save work first.
- **Long comments are this repo's institutional memory.** Move them with the
  code they explain; don't drop them in the shuffle.

## Open questions

- **Is a second host actually coming?** If yes (server, Mac), the payoff jumps
  and nix-darwin's class should be designed for from step 5. If no, steps 1–4
  alone may be enough.
- **Keep the stow dotfiles separate?** `~/nix-hypr-dotfiles` (hypr, waybar,
  wofi, foot, ghostty…) is deliberately outside Nix so it can be edited live.
  The dendritic `hyprland.nix` could own those via home-manager, at the cost of
  a rebuild per tweak. Default: leave them alone.
- **Granularity of `cli-tools`.** One module, or one per tool? Start coarse.
