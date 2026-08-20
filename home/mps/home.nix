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
    # Disabled: keep your live breeze-dark GTK theme (Plasma). HM refused to
    # overwrite the existing gtk-3.0/gtk-4.0 settings + ~/.gtkrc-2.0. Your GTK
    # apps are already dark via those live files; the dconf prefer-dark hint
    # below still drives Electron/browser dark mode. Flip back to true (and
    # remove the live files) if you want HM to own the theme.
    enable = false;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
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
