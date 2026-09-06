####################################################################
# Steam / gaming
#
# Everything required to play games on this machine, in one file. Nothing
# else in the config depends on it: delete the `./gaming.nix` line from
# configuration.nix's `imports` and the desktop is exactly as it was.
#
# PORTABLE — nothing here is sys76-specific. The one machine-dependent
# concern (this laptop runs the NVIDIA card in PRIME *offload* mode, so
# games land on the Intel iGPU unless you say otherwise) is documented in
# the "Running games on the dGPU" section at the bottom, but it is prose,
# not configuration. On a single-GPU machine that section simply doesn't
# apply and the rest of this file still works unchanged.
#
# Written for the migration off Garuda, where Steam was installed
# imperatively (`pacman -S steam`) and the 32-bit half of the graphics
# stack came along for free because Arch's multilib repo was enabled
# globally. NixOS asks for both of those explicitly — see below.
####################################################################

{ config, lib, pkgs, ... }:

{
  ####################################################################
  # Steam itself
  ####################################################################
  # The MODULE, not the package. `environment.systemPackages = [ pkgs.steam ]`
  # gets you a binary that won't run: Steam is a proprietary blob expecting a
  # normal FHS filesystem (/usr/lib, /lib32), and it needs udev rules to see
  # controllers and firewall holes to talk to the network. This module wires
  # all of that — the FHS sandbox wrapper, hardware.steam-hardware (controller
  # udev rules, implied by enable), and the firewall options below.
  programs.steam = {
    enable = true;

    # Streaming a game from this machine to another device on the LAN
    # (phone, TV, Steam Deck). Opens the ports the client needs to find it.
    remotePlay.openFirewall = true;

    # Copy an already-downloaded game from another Steam machine on the LAN
    # instead of re-downloading 80GB from Valve. Free win on a metered or
    # slow connection; harmless otherwise.
    localNetworkGameTransfers.openFirewall = true;

    # `protontricks` — winetricks aimed at Proton prefixes. The escape hatch
    # for the one game that needs a DLL or a registry poke to start. Enabled
    # via the module rather than the bare package so it can see Steam's
    # library paths from inside the FHS environment.
    protontricks.enable = true;

    # Steam Input's controller remapping drives games by synthesizing X11
    # XTEST events, which do not exist on Wayland — so remapped controls
    # silently do nothing in a native Wayland game. extest is a shim that
    # translates those into uinput events instead. This is a Wayland-desktop
    # concern specifically, which is to say: this machine.
    extest.enable = true;

    # GE-Proton — the community Proton build with extra media codecs and
    # per-game patches that land months before Valve's. Declaring it here
    # makes it appear in Steam's "Compatibility > Force the use of a specific
    # Steam Play tool" dropdown. Note this pins GE-Proton to whatever version
    # nixpkgs has: it updates on `nix flake update` like everything else,
    # instead of via ProtonUp. That is the point — same rollback story as the
    # rest of the system.
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  ####################################################################
  # 32-bit graphics — the actual reason Steam fails to start on NixOS
  ####################################################################
  # `hardware.graphics.enable = true` in configuration.nix covers 64-bit only.
  # The Steam client is a 32-bit program, as are a large number of older
  # native Linux games and every 32-bit Windows game run through Proton, and
  # all of them need a 32-bit Mesa/Vulkan/libGL to draw anything.
  #
  # Without this line Steam either refuses to launch or opens to a black or
  # garbled window. It is the single most common "Steam is broken on NixOS"
  # cause, and the failure gives no useful message.
  #
  # On this machine it also pulls in the 32-bit NVIDIA userspace libraries
  # automatically — hardware.nvidia in hardware-sys76.nix contributes them to
  # the 32-bit driver set once this is on. No separate lib32 package needed.
  hardware.graphics.enable32Bit = true;

  ####################################################################
  # 32-bit audio
  ####################################################################
  # Same argument as the graphics stack above: a 32-bit game links against a
  # 32-bit ALSA/Pulse client library. Without this the game runs, renders,
  # and is completely silent.
  #
  # configuration.nix deliberately left this off and pointed here. The cost it
  # documented is real and unchanged: this drags i686 builds of the audio
  # stack into every nixpkgs bump, and Hydra's i686 coverage is thin enough
  # that some of those miss cache.nixos.org and compile on this machine. That
  # is the price of sound in 32-bit games; there is no cheaper version of it.
  services.pipewire.alsa.support32Bit = true;

  ####################################################################
  # Performance helpers
  ####################################################################
  # GameMode — a daemon games ask (via a library call Proton and many native
  # titles already make) to temporarily switch the CPU governor to
  # performance, raise the game's I/O and scheduling priority, and inhibit
  # the screensaver. It does nothing until a game requests it, so there is no
  # idle cost. Force it on for a game that doesn't ask by prefixing its
  # launch options with `gamemoderun %command%`.
  programs.gamemode.enable = true;

  # Gamescope — Valve's micro-compositor (the thing the Steam Deck runs).
  # Useful here for three specific problems: a game that insists on changing
  # your desktop resolution, a game that mis-handles this 4K panel's scaling,
  # and upscaling (render at 1080p, present at 2160p — real framerate on a
  # laptop dGPU). Use per game with `gamescope -W 3840 -H 2160 -w 1920 -h 1080
  # -f -- %command%` in launch options.
  programs.gamescope = {
    enable = true;

    # DELIBERATELY off (which is also the default — stated explicitly because
    # every guide online tells you to turn it on). capSysNice setcaps the
    # gamescope binary so it can raise its own scheduling priority. With
    # native Steam that breaks the thing you wanted it for: a game launched
    # with gamescope in its launch options dies with "failed to inherit
    # capabilities: Operation not permitted", because the setcap'd binary
    # refuses Steam's LD_PRELOAD environment. See NixOS/nixpkgs#351516.
    #
    # What is lost: gamescope runs at normal priority. In practice that
    # matters far less than gamescope not starting at all.
    capSysNice = false;
  };

  ####################################################################
  # Gaming-adjacent packages
  ####################################################################
  # Kept minimal on purpose — the launchers below are each a large closure,
  # so add them when you actually have a non-Steam game to run, not now.
  #   lutris  — GOG/Epic/emulators/arbitrary Windows games, Wine per-prefix
  #   heroic  — Epic + GOG + Amazon, nicer UI, narrower scope than Lutris
  #   bottles — general Wine prefix manager
  environment.systemPackages = with pkgs; [
    # Frametime/FPS/temp/GPU overlay. The tool that answers "is this game
    # actually running on the 4070?" without alt-tabbing to nvidia-smi —
    # it names the rendering GPU in the overlay. Enable per game with
    # `mangohud %command%` in launch options.
    mangohud
  ];

  ####################################################################
  # Running games on the dGPU  (READ THIS — machine-specific behaviour)
  ####################################################################
  # hardware-sys76.nix runs the RTX 4070 in PRIME OFFLOAD mode: the Intel
  # iGPU drives the panel and the NVIDIA card stays asleep until an app is
  # explicitly launched onto it. That is the right default for battery life
  # and it is why Hyprland is stable here — but it means:
  #
  #   A GAME LAUNCHED NORMALLY FROM STEAM RENDERS ON THE INTEL iGPU.
  #
  # It will run. It will run badly, and nothing will tell you why. Per game:
  # Properties > General > Launch Options:
  #
  #   nvidia-offload %command%
  #
  # `nvidia-offload` already exists on this system — it comes from
  # prime.offload.enableOffloadCmd in hardware-sys76.nix. Composing with the
  # helpers above, a fully loaded launch option looks like:
  #
  #   nvidia-offload gamemoderun mangohud %command%
  #
  # Confirm it worked: mangohud's overlay should name the NVIDIA GPU, not
  # Intel. Leave Steam ITSELF on the iGPU — the client is a web browser and
  # has no business waking a 4070.
  #
  # The alternative is switching hardware-sys76.nix to `prime.sync.enable =
  # true`, which puts everything on the NVIDIA card and makes launch options
  # unnecessary. It costs battery life, and that file's own notes flag it as
  # the more likely of the two modes to break Hyprland. Not recommended for a
  # laptop that is a workstation first.
}
