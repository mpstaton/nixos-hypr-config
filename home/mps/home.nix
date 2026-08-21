{ config, pkgs, lib, inputs, ... }:

{
  home.username = "mps";
  home.homeDirectory = "/home/mps";
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  ####################################################################
  # hypridle — ported from garuda-hyprland-config/dotconfig/hypr/hypridle.conf
  ####################################################################
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 150;
          on-timeout = "brightnessctl -s set 10";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 150;
          on-timeout = "brightnessctl -sd rgb:kbd_backlight set 0";
          on-resume = "brightnessctl -rd rgb:kbd_backlight";
        }
        {
          timeout = 900; # 15 min — home desktop, don't nag for the password
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 330;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  # hyprlock replaces swaylock (in the Hypr ecosystem, GPU-accelerated,
  # no dependency on a Garuda-provided wallpaper path).
  programs.hyprlock.enable = true;

  ####################################################################
  # mako — ported from garuda-hyprland-config/dotconfig/mako/config
  ####################################################################
  services.mako = {
    enable = true;
    settings = {
      anchor = "bottom-right";
      font = "monospace 10";
      background-color = "#000000";
      text-color = "#ff0000";
      width = 350;
      margin = "0,20,20";
      padding = "10";
      border-size = 1;
      border-color = "#ff0000";
      border-radius = 5;
      default-timeout = 10000;
      group-by = "summary";
      icons = 1;
    };
  };

  ####################################################################
  # Shell — fish + starship
  # (Arch/Garuda-only aliases dropped: pacman/paru/reflector/garuda-update/
  # meld-pacdiff. NixOS equivalents added where one makes sense.)
  ####################################################################
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting
      set VIRTUAL_ENV_DISABLE_PROMPT "1"
      set -xU MANPAGER "sh -c 'col -bx | bat -l man -p'"
      set -xU MANROFFOPT "-c"
      set -U __done_min_cmd_duration 10000
      set -U __done_notification_urgency_level low
    '';
    shellAliases = {
      ls = "eza -al --color=always --group-directories-first --icons";
      lsz = "eza -al --color=always --total-size --group-directories-first --icons";
      la = "eza -a --color=always --group-directories-first --icons";
      ll = "eza -l --color=always --group-directories-first --icons";
      lt = "eza -aT --color=always --group-directories-first --icons";
      cat = "bat --style header --style snip --style changes --style header";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      grep = "ugrep --color=auto";
      # NixOS equivalents of the old Garuda maintenance aliases
      upd = "sudo nixos-rebuild switch --flake ~/code/nixos-hypr-config#hypr-nix";
      updflake = "nix flake update --flake ~/code/nixos-hypr-config";
      gc = "sudo nix-collect-garbage --delete-older-than 30d";
      rollback = "sudo nixos-rebuild switch --rollback";
    };
    functions = {
      backup = "cp $argv[1] $argv[1].bak";
    };
  };

  # Starship is enabled here for the fish integration only — the prompt
  # itself lives in the nix-hypr-dotfiles stow repo, at
  # starship/.config/starship.toml.
  #
  # Deliberately no `settings`. Home Manager only writes
  # ~/.config/starship.toml when settings != {} (see the module's
  # `hasGeneratedConfig`), so leaving it empty frees that path for stow to
  # own. Add a single setting here and HM reclaims the file, which makes
  # `stow starship` fail on a conflict.
  #
  # This follows the same rule as hypr/waybar/wofi/ghostty: config that gets
  # tuned often belongs in the stow repo, where an edit takes effect on the
  # next prompt instead of on the next rebuild.
  programs.starship.enable = true;

  programs.git = {
    enable = true;
    # CHANGE ME
    settings.user.name = "mpstaton";
    settings.user.email = "mpstaton@gmail.com";
  };

  ####################################################################
  # Editors — kept as their own tool, not re-authored in Nix.
  # LazyVim (nvim) and Helix already have their own config directories in
  # garuda-hyprland-config/dotconfig/{nvim,helix}. Simplest correct move:
  # after first boot, clone that repo and symlink those two directly —
  # LazyVim manages its own plugin lockfile, which is out of scope for
  # what Nix should own.
  #   ln -sfn ~/code/garuda-hyprland-config/dotconfig/nvim ~/.config/nvim
  #   ln -sfn ~/code/garuda-hyprland-config/dotconfig/helix ~/.config/helix
  ####################################################################
  home.packages = with pkgs; [
    neovim
    helix
    ripgrep
    fd
    fzf
    bat
    eza
    zoxide
    tealdeer
    yazi
    lazygit

    # Node 24 for deepseek-harness (dsh), which is built from source at
    # ~/code/deepseek-harness rather than packaged — it ships no flake, and
    # its pnpm monorepo would need a vendored-deps hash that breaks on every
    # upstream bump of a project whose README promises breaking changes.
    # Its engines field wants ^22.19 || >=24. pnpm comes from configuration.nix.
    nodejs_24
  ];

  ####################################################################
  # Cursor / GTK — minimal starting point; port Kvantum "Sweet" / qt5ct
  # from the old config later if you care about matching it pixel-for-pixel.
  ####################################################################
  # Disabled: keep your live breeze_cursors (from Plasma) instead of Bibata.
  # This block wrote cursor lines into ~/.gtkrc-2.0 / gtk-3.0 settings, which
  # HM refused to clobber. Re-enable if you ever want HM to own the cursor.
  # home.pointerCursor = {
  #   gtk.enable = true;
  #   package = pkgs.bibata-cursors;
  #   name = "Bibata-Modern-Classic";
  #   size = 24;
  # };

  ####################################################################
  # Dark mode — applied to both desktops.
  #
  #  - GTK apps (Thunar, GParted, Inkscape, ...) use Adwaita-dark.
  #  - The freedesktop "prefer-dark" hint below is what Electron apps
  #    (VS Code, Obsidian, Discord) and the browsers read through the
  #    xdg-desktop-portal, so they follow dark automatically under Hyprland.
  #  - KDE Plasma's own shell + Qt apps go dark via plasma-manager
  #    (programs.plasma below).
  #
  # (Qt apps launched *inside a Hyprland session* aren't themed here yet —
  # that's the qt5ct/Kvantum "Sweet" port the cursor/GTK comment defers.)
  ####################################################################
  gtk = {
    # Enabled 2026-08-20. Previously false, on the premise that the live
    # kde-gtk-config files already made GTK apps dark — they did not. Those
    # files set no gtk-theme-name at all (~/.gtkrc-2.0 had it literally empty),
    # and their colors.css was 5KB of @define-color with zero applied rules,
    # so Thunar fell back to stock light Adwaita. HM now owns these files.
    enable = true;

    # Same upstream project as Ghostty's Carbonfox theme (nightfox.nvim), then
    # recolored below so the backgrounds match Ghostty exactly rather than just
    # closely. Chosen over Graphite-Dark, whose #2C2C2C background is lighter
    # than the terminal it sits next to.
    theme = {
      name = "Nightfox-Dark";
      # Recolored in-package to Ghostty's Carbonfox background (#161616).
      #
      # This cannot be done from ~/.config/gtk-3.0/gtk.css: Nightfox-Dark
      # hardcodes its palette as literals (55 hex + 256 rgba occurrences of the
      # background alone) and never references @theme_bg_color, so redefining
      # @define-color there resolves to nothing — the same way the old
      # kde-gtk-config colors.css defined 5KB of colors that nothing read.
      #
      # Mapping is Nightfox's dark ramp onto Carbonfox's, so the theme keeps its
      # internal light/dark relationships instead of going flat:
      #   #0e131b bg0 -> #0e0e0e    #192330 bg1 -> #161616  (Ghostty's exact bg)
      #   #212e3f bg2 -> #1c1c1c    #29394f bg3 -> #2a2a2a  (Carbon's selection)
      #   #3c4756 bg4 -> #353535
      # Foreground and the #719cd6 accent are deliberately left alone.
      package = pkgs.nightfox-gtk-theme.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          for d in $out/share/themes/Nightfox-Dark*; do
            find "$d" -type f -exec sed -i \
              -e 's/#0e131b/#0e0e0e/gI' \
              -e 's/#192330/#161616/gI' \
              -e 's/#212e3f/#1c1c1c/gI' \
              -e 's/#29394f/#2a2a2a/gI' \
              -e 's/#3c4756/#353535/gI' \
              -e 's/rgba(20, *28, *38/rgba(16, 16, 16/gI' \
              -e 's/rgba(25, *35, *48/rgba(22, 22, 22/gI' \
              -e 's/rgba(33, *46, *63/rgba(28, 28, 28/gI' \
              {} +
          done
        '';
      });
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Noto Sans";
      size = 10;
    };

    # Cursor carried over from the kde-gtk-config files this block replaces;
    # without it the cursor reverts to the default theme. Render size is NOT
    # set here — gtk-xft-dpi was a Plasma leftover, and scaling now lives in
    # hyprland.conf as env = GDK_DPI_SCALE,1.67 so Hyprland owns it.
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-cursor-theme-name = "breeze_cursors";
      gtk-cursor-theme-size = 24;
      gtk-decoration-layout = "icon:minimize,maximize,close";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-cursor-theme-name = "breeze_cursors";
      gtk-cursor-theme-size = 24;
      gtk-decoration-layout = "icon:minimize,maximize,close";
    };

    # Background-only transparency, mirroring Ghostty's background-opacity: the
    # surface goes translucent (Hyprland's global blur sits behind it) while
    # text and icons stay fully opaque. A Hyprland `opacity` window rule cannot
    # express this — it fades the entire window, text included.
    #
    # Alpha is the one knob here: 0.85 is subtle, Ghostty itself runs 0.6.
    #
    # Caveat: this is user-wide GTK3 CSS. GTK has no per-application selector,
    # so every GTK3 app gets the translucent background, not just Thunar.
    # Delete this block to go back to fully opaque.
    gtk3.extraCss = ''
      window.background,
      .background {
        background-color: rgba(22, 22, 22, 0.85);
      }

      /* The theme paints these surfaces opaque over the window background;
         clear them so the translucency is actually visible in the file list
         and sidebar rather than only in the thin window margins. */
      .view,
      treeview.view,
      scrolledwindow,
      notebook,
      notebook > stack,
      paned,
      .sidebar {
        background-color: transparent;
      }
    '';
  };

  # Drives the xdg-desktop-portal "color-scheme" that Electron/Chromium/
  # Firefox query — this is what makes them dark under Hyprland.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # KDE Plasma 6: default the whole workspace to Breeze Dark. overrideConfig
  # stays at its default (false), so this sets only the color scheme/look and
  # leaves any later manual KDE tweaks in place.
  programs.plasma = {
    enable = true;
    workspace = {
      colorScheme = "BreezeDark";
      lookAndFeel = "org.kde.breezedark.desktop";
    };
  };
}
