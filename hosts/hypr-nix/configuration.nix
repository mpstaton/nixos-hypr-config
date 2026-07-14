{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  ####################################################################
  # Boot / bootloader
  ####################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Keep enough generations in the boot menu to roll back after a bad
  # update — this is the actual fix for "the machine rotted because I
  # didn't update it often enough": every switch is a new, bootable,
  # rollback-able generation instead of an in-place mutation.
  boot.loader.systemd-boot.configurationLimit = 15;

  ####################################################################
  # Networking
  ####################################################################
  networking.hostName = "hypr-nix"; # CHANGE ME if you want a different hostname
  networking.networkmanager.enable = true;

  # Broad firmware coverage (Wi-Fi/Bluetooth chipsets on laptops frequently
  # need non-free firmware blobs to be recognized as a device at all —
  # this is almost certainly why Wi-Fi disappeared on the vanilla install).
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  # CHANGE ME — pick your real time zone (`timedatectl list-timezones`).
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  ####################################################################
  # Users
  ####################################################################
  users.users.mps = {
    isNormalUser = true;
    description = "mps";
    extraGroups = [ "networkmanager" "wheel" "video" "input" "audio" "docker" ];
    shell = pkgs.bash; # default login shell; fish is still installed below
  };
  programs.fish.enable = true; # available via `fish`, just not the default

  ####################################################################
  # Docker — enabled as a SERVICE, not just a package. This one line sets up
  # the daemon, the `docker` CLI, containerd (bundled — no separate install),
  # the socket + systemd units, and the `docker compose` plugin. The `docker`
  # group added to the user above lets you run docker without sudo.
  # (docker-desktop is NOT in nixpkgs and is redundant on Linux — the engine is
  # native here, no VM. Use `lazydocker`/`portainer` if you want a GUI later.)
  ####################################################################
  virtualisation.docker.enable = true;

  # Portainer isn't a package — it's a container. Run it declaratively as a
  # systemd-managed OCI container (starts on boot). Web UI at https://localhost:9443
  # (first visit: create an admin user). It mounts the docker socket to manage
  # the local engine, and a named volume for its own data.
  virtualisation.oci-containers = {
    backend = "docker";
    containers.portainer = {
      image = "portainer/portainer-ce:latest";
      autoStart = true;
      ports = [ "9443:9443" ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "portainer_data:/data"
      ];
    };
  };

  ####################################################################
  # Hyprland — the whole point of this machine
  ####################################################################
  programs.hyprland = {
    enable = true;
    withUWSM = true; # recommended launch path; integrates with systemd/greetd
    xwayland.enable = true;
  };

  # Electron apps (Obsidian, VS Code/Windsurf, Discord, etc.) render via
  # native Wayland instead of falling back to XWayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Screensharing (matches xdg-desktop-portal-hyprland from the Hyprland
  # NixOS module) + a GTK portal for file pickers in non-GTK apps.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Login manager: SDDM (graphical), shared by both desktops. SDDM lists every
  # installed session at login, so you choose KDE Plasma *or* Hyprland on a
  # per-login basis — this is what makes the dual-desktop setup switchable.
  # (Swapped in for the original greetd+tuigreet, which was hardcoded to launch
  # only Hyprland; NixOS permits just one display manager at a time.)
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;

  # This panel is 4K (3840x2160). SDDM's greeter has no scaling by default, so
  # the session picker renders at ~half the size you can comfortably read — the
  # reason Hyprland "wasn't offered" (it was listed, just microscopic). Doubling
  # the Qt font DPI (96 -> 192, i.e. 2x) makes the greeter legible on HiDPI.
  # Bump/lower this one number to taste (144 = 1.5x, 168 = 1.75x).
  systemd.services.display-manager.environment.QT_FONT_DPI = "192";

  # Land in Hyprland by default instead of Plasma. You can still switch to
  # "Plasma" at the (now-readable) SDDM session picker on any given login.
  # "hyprland-uwsm" matches withUWSM = true above (the recommended launch path);
  # use "hyprland" for the plain session.
  services.displayManager.defaultSession = "hyprland-uwsm";

  # KDE Plasma 6 — kept alongside Hyprland as a full fallback desktop. If
  # Hyprland ever misbehaves, log out and pick "Plasma" at the SDDM screen: no
  # reboot or rollback required. The Hyprland home-manager config (waybar,
  # wofi, mako, etc.) simply stays idle while you're in a Plasma session.
  services.desktopManager.plasma6.enable = true;

  # Needed so the home-manager dconf "prefer-dark" setting (and gsettings in
  # general) applies in the Hyprland session too, not only under Plasma.
  programs.dconf.enable = true;

  # 1Password — dedicated modules (not just the plain package) so the GUI's
  # polkit unlock prompt and browser-integration socket actually work.
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "mps" ];
  };

  security.polkit.enable = true;
  # hyprpolkitagent — the actively-maintained Qt/QML polkit agent from the Hypr
  # ecosystem (garuda-hyprland-config used polkit-gnome, unmaintained upstream),
  # started from Hyprland's exec-once in home.nix. Installed via the single
  # environment.systemPackages list below (defining that option twice in one
  # module is an evaluation error, so it lives with the rest of the packages).

  ####################################################################
  # Graphics
  ####################################################################
  # NOTHING below this comment is required to install or boot. This one
  # line is the entire hardware-specific graphics requirement:
  hardware.graphics.enable = true;
  #
  # It gets you a working desktop on ANY GPU vendor with zero branching:
  #   - Intel/AMD: mesa handles it directly.
  #   - NVIDIA: the in-kernel `nouveau` driver (open-source, ships in the
  #     kernel already) drives the display with no extra config.
  # This is why you don't need to know your GPU before installing — the
  # generic path just works. `nixos-generate-config` also auto-detects an
  # NVIDIA card via lspci during install and drops a commented hint into
  # hardware-configuration.nix if it finds one, as a second confirmation.
  #
  # The blocks below are a purely OPTIONAL later upgrade — proprietary
  # NVIDIA driver for better 3D/power performance than nouveau. Nothing
  # forces this decision now: get to a first successful boot, then run
  #   lspci -k | grep -A2 -E "(VGA|3D)"
  # on the running system (or from the live USB before you ever touch the
  # disk — see README "Identify hardware" step) and uncomment if relevant.

  # -- Confirmed: Intel + NVIDIA hybrid laptop (Optimus-style). Nouveau will
  # drive the display out of the box with zero config below — this block is
  # the optional upgrade to the proprietary driver + PRIME offload (iGPU
  # drives the internal panel full-time; NVIDIA wakes up only for apps you
  # explicitly launch on it — better battery life than discrete-only mode).
  #
  # Two bus IDs are the only genuinely hardware-specific values left, and
  # the SAME `lspci -k | grep -A2 -E "(VGA|3D)"` from the README gives you
  # both in one shot, e.g.:
  #   00:02.0 VGA compatible controller: Intel Corporation ...   -> PCI:0:2:0
  #   01:00.0 3D controller: NVIDIA Corporation ...              -> PCI:1:0:0
  # (bus:device.function in lspci -> "PCI:bus:device:function", each in decimal)
  #
  # services.xserver.videoDrivers = [ "nvidia" ];
  # hardware.nvidia = {
  #   modesetting.enable = true; # also enables early KMS (nixpkgs default post-535)
  #   open = true; # open kernel module — required on 50-series, recommended Turing+
  #   nvidiaSettings = true;
  #   powerManagement.enable = true; # correct suspend/resume on hybrid laptops
  #   package = config.boot.kernelPackages.nvidiaPackages.stable;
  #   prime = {
  #     offload.enable = true;
  #     offload.enableOffloadCmd = true; # adds a `nvidia-offload <cmd>` wrapper
  #     intelBusId = "PCI:CHANGE:ME:0";
  #     nvidiaBusId = "PCI:CHANGE:ME:0";
  #   };
  # };
  #
  # Also add to home/mps/home.nix's hyprland `env` list once enabled (fixes
  # the two most common hybrid-graphics symptoms — GLX vendor mismatch and
  # Electron/Obsidian/Joplin flicker from running under XWayland):
  #   "LIBVA_DRIVER_NAME,nvidia"
  #   "__GLX_VENDOR_LIBRARY_NAME,nvidia"
  #   "ELECTRON_OZONE_PLATFORM_HINT,auto"

  ####################################################################
  # Audio / Bluetooth
  ####################################################################
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  ####################################################################
  # Filesystem services / peripherals
  ####################################################################
  services.gvfs.enable = true; # Thunar network/trash/mtp support
  services.udisks2.enable = true;
  services.fwupd.enable = true; # firmware updates — useful on laptops
  services.printing.enable = true;

  ####################################################################
  # Fonts (nerd fonts feed waybar/wofi glyphs + the custom/* icon modules)
  ####################################################################
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];

  ####################################################################
  # System-wide packages
  # (User-facing app *configuration* — hyprland.conf, waybar, wofi, mako,
  # fish, starship — lives in home/mps/home.nix. This list is base
  # binaries + the handful of GUI apps that were bound to function keys
  # in the old hyprland.conf.)
  ####################################################################
  nixpkgs.config.allowUnfree = true; # needed for warp-terminal, vscode, etc.

  environment.systemPackages = with pkgs; [
    git
    gh
    curl
    wget
    killall
    unzip
    claude-code
    stow            # GNU Stow — manages the ~/nix-hypr-dotfiles symlink farm

    # Container tooling / GUIs (Docker engine itself is the service above)
    lazydocker      # terminal UI for docker
    podman-desktop  # desktop GUI (manages the docker socket too)

    # Dev tools (were `nix profile install`-ed; now declarative)
    jujutsu         # `jj` — git-compatible VCS
    helix           # `hx` — modal terminal editor
    nvd             # nix closure diff (used by the update-preview ritual)
    vscode          # VS Code (unfree; allowUnfree is set below)
    pnpm            # fast Node package manager
    uv              # fast Python package/proj manager (Astral)
    superfile       # `spf` — modern terminal file manager
    nushell         # `nu` — structured-data shell (available to run; not the login shell)
    brave           # Brave browser
    kdePackages.kdenlive   # KDE video editor
    switcheroo      # image converter / resizer GUI
    resources       # modern system monitor GUI
    onlyoffice-desktopeditors   # office suite (docs/sheets/slides)
    curtail         # image compressor GUI

    # CLI tools & media utilities (ported from the Mac)
    ffmpeg
    imagemagick
    tesseract       # OCR
    ghostscript
    fontforge
    ripgrep         # `rg`
    tree
    zoxide          # smarter `cd` (needs shell init to fully work)
    railway         # Railway.app CLI
    flyctl          # Fly.io CLI  (you wrote "flytl")
    glow            # markdown pager
    git-lfs
    pandoc
    surrealdb
    surrealist      # SurrealDB GUI / query explorer
    tldr
    tmux
    turso-cli       # Turso CLI (`turso`)
    zellij          # terminal multiplexer
    atuin           # shell history (needs shell init to fully work)
    # note: fish + starship already configured in home/mps/home.nix (not duplicated here)
    inputs.hunk.packages.${pkgs.system}.default   # `hunk` — terminal diff viewer

    # Wayland / desktop tools (were `nix profile install`-ed; now declarative)
    hyprshot        # screenshots (Print binds)
    satty           # screenshot annotator

    # Wayland session utilities used directly by hyprland.conf binds
    hyprpolkitagent # polkit agent (see security.polkit above)
    brightnessctl
    pamixer
    pavucontrol # GUI volume mixer — waybar audio module, right-click
    alsa-utils # alsamixer — waybar audio module, left-click
    libnotify # notify-send, used by the volume/brightness/screenshot binds
    playerctl
    grim
    slurp
    swappy
    wl-clipboard
    cliphist
    jq # used by the ported screenshot scripts

    wpaperd # wallpaper daemon
    networkmanagerapplet # nm-applet in the tray

    # Launcher / menus / bar
    wofi
    nwg-launchers # nwgbar (power menu)
    nwg-drawer

    # File managers
    thunar
    thunar-volman
    ranger

    # Terminals (Warp is the daily driver; kitty/foot are bound directly
    # in hyprland.conf)
    warp-terminal
    kitty
    foot
    alacritty
    ghostty

    # Function-key app row from the old Garuda config (Garuda-only tools
    # — garuda-welcome, snapper-tools, calamares, garuda-*-manager — are
    # dropped: NixOS generations/rollback replace snapper's job here, and
    # the rest have no NixOS equivalent).
    firefox
    vivaldi # default browser — set via xdg.mimeApps in home.nix
    thunderbird
    geany
    gitkraken # replaces github-desktop (not packaged); swap freely
    gparted
    inkscape
    blender
    meld
    joplin-desktop
    galculator

    btop
    htop
  ] ++ [
    # Zen Browser comes from a flake input, not nixpkgs — see flake.nix
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Default $EDITOR (both neovim and helix are installed via home.nix;
  # neovim wins as the default).
  environment.variables.EDITOR = "nvim";

  ####################################################################
  # Nix itself
  ####################################################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # Optional: pull the flake's own update onto a schedule instead of
  # relying on remembering to do it by hand (the exact failure mode that
  # took down the Garuda box). Off by default so you stay in control of
  # *when* a rebuild happens; flip to true once you trust the flow.
  system.autoUpgrade.enable = false;
  # system.autoUpgrade.flake = "git+file:///home/mps/code/nixos-hypr-config";
  # system.autoUpgrade.flags = [ "--update-input" "nixpkgs" "-L" ];
  # system.autoUpgrade.dates = "weekly";

  system.stateVersion = "26.05";
}
