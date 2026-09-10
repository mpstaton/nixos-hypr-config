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

  # ...but enabling the daemon is only half of it. A game "asks" for GameMode
  # by dlopen()ing libgamemode.so, and Steam runs everything inside an FHS
  # sandbox whose /usr/lib contains only what this module was told to put
  # there. The system-wide gamemode package is NOT visible in there, so every
  # request fails and the daemon above sits idle. Observed on this machine
  # before the fix, in ~/.local/share/Steam/logs/console-linux.txt:
  #
  #   gamemodeauto: dlopen failed - libgamemode.so: cannot open shared object
  #   file: No such file or directory
  #
  # Nothing surfaces this in the UI — GameMode simply never engages, and the
  # only symptom is the framerate you never got.
  #
  # `extraLibraries` is the module's hook for adding libraries to that
  # sandbox. It is invoked twice, once per architecture, with the matching
  # nixpkgs set — so this single line lands the 64-bit lib in /usr/lib64 for
  # games and the 32-bit lib in /usr/lib32 for the Steam client itself (note
  # /usr/lib is a symlink to /usr/lib64 in there, which makes the 64-bit copy
  # look absent from outside the sandbox — it isn't). The `.lib` output is
  # just the shared objects, not the daemon and CLI.
  #
  # This makes the AUTOMATIC path work. The explicit `gamemoderun %command%`
  # documented at the bottom of this file never needed it and still works.
  programs.steam.package = pkgs.steam.override {
    extraLibraries = p: [ p.gamemode.lib ];
  };

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
  # Keep the Steam CLIENT off the dGPU  (fixes the unnavigable-UI lag)
  ####################################################################
  # Upstream's steam.desktop ships these two keys:
  #
  #     PrefersNonDefaultGPU=true
  #     X-KDE-RunOnDiscreteGpu=true
  #
  # They are a request to the launcher: "start me on the discrete card."
  # Launchers that honour it (nwg-drawer, KDE's Kickoff, GNOME Shell) grant
  # it the only way the freedesktop spec knows how — by exporting
  # DRI_PRIME=1 into the process. On a normal Mesa-only PRIME laptop that is
  # correct and harmless. On THIS machine it is neither, because the dGPU is
  # driven by the proprietary NVIDIA driver, which Mesa cannot render on
  # directly. Measured on this box:
  #
  #   (no vars)      -> Mesa Intel(R) Graphics (RPL-S)          <- iGPU, native
  #   DRI_PRIME=1    -> zink Vulkan 1.4(NVIDIA ... PROPRIETARY)  <- GL-on-Vulkan
  #   nvidia-offload -> NVIDIA GeForce RTX 4070 Laptop GPU       <- dGPU, native
  #
  # DRI_PRIME=1 does not get you the NVIDIA GL driver. It gets you ZINK —
  # Mesa's OpenGL-on-Vulkan translation layer — stacked on the proprietary
  # Vulkan driver. Steam's UI is Chromium (steamwebhelper/CEF), and
  # CEF-on-Zink-on-proprietary-NVIDIA-on-XWayland segfaults its GPU process
  # repeatedly (exit_code=139 in ~/.local/share/Steam/logs/cef_log.txt).
  # After enough crashes Chromium gives up and disables GPU compositing, so
  # the entire client repaints on the CPU: scrolling stutters and clicks land
  # seconds late. That is the "Steam is unnavigable" bug, and nothing about
  # it announces itself — the UI just gets slow.
  #
  # So: flip both keys off. This is the enforcement of the advice the dGPU
  # section below already gives in prose — "leave Steam ITSELF on the iGPU,
  # the client is a web browser and has no business waking a 4070." Games
  # still reach the 4070, via `nvidia-offload %command%` per game; that path
  # is native NVIDIA GL and is unaffected by this.
  #
  # Patched rather than replaced so the upstream file keeps its nine desktop
  # actions and its ~25 translations. `--replace-fail` so a rename upstream
  # breaks the build loudly instead of silently restoring the lag.
  nixpkgs.overlays = [
    (final: prev: {
      steam-unwrapped = prev.steam-unwrapped.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          substituteInPlace $out/share/applications/steam.desktop \
            --replace-fail 'PrefersNonDefaultGPU=true'   'PrefersNonDefaultGPU=false' \
            --replace-fail 'X-KDE-RunOnDiscreteGpu=true' 'X-KDE-RunOnDiscreteGpu=false'
        '';
      });
    })
  ];

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
