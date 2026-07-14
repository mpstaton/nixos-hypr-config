{ config, pkgs, lib, inputs, ... }:

{
  home.username = "mps";
  home.homeDirectory = "/home/mps";
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  ####################################################################
  # Default browser — Vivaldi. Firefox and Zen Browser are installed
  # (configuration.nix) but not wired up as handlers, so they stay
  # available without stealing the default.
  ####################################################################
  xdg.mimeApps = {
    # Disabled: HM won't clobber your existing ~/.config/mimeapps.list. Set
    # default apps via Plasma / `xdg-mime` instead. (Also these pointed at
    # vivaldi, which isn't installed.)
    enable = false;
    defaultApplications = {
      "text/html" = "vivaldi-stable.desktop";
      "x-scheme-handler/http" = "vivaldi-stable.desktop";
      "x-scheme-handler/https" = "vivaldi-stable.desktop";
      "x-scheme-handler/about" = "vivaldi-stable.desktop";
      "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
    };
  };

  ####################################################################
  # Hyprland — ported from garuda-hyprland-config/dotconfig/hypr/hyprland.conf
  #
  # Dropped on purpose (Garuda/Arch-only, no NixOS equivalent):
  #   - edex-ui bind, garuda-welcome/garuda-locale.sh/mon.sh execs
  #   - the "Install Garuda Hyprland" (calamares.sh) and
  #     "enable G-Hyprland" (implement_gum.sh) binds
  #   - the legacy `xrdb -load ~/.Xresources` exec (pure-X11 leftover)
  #   - F11 snapper-tools: NixOS generations + `nixos-rebuild --rollback`
  #     already give you this, declaratively, for the whole system
  ####################################################################
  wayland.windowManager.hyprland = {
    # Disabled: HM's Lua backend miscompiles this and writes an ignored
    # hyprland.lua; the REAL config is hand-placed at ~/.config/hypr/hyprland.conf
    # (moving to a stow repo). Leaving the settings below as dead reference.
    enable = false;
    xwayland.enable = true;
    # UWSM (enabled in configuration.nix) manages the session lifecycle;
    # the Home Manager module's own systemd integration must stay off.
    systemd.enable = false;

    settings = {
      monitor = [
        "eDP-2, 3840x2160@144.00101, 0x0, 1.25"
        "DP-2, disable"
        "DP-3, 3840x2160@60, 3072x0, 1.5"
      ];

      "$mainMod" = "SUPER";

      exec-once = [
        "nm-applet --indicator"
        "hypridle"
        "wpaperd"
        "waybar"
        "mako"
        "hyprpolkitagent"
        "foot --server"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      env = [ "XDG_CURRENT_DESKTOP,Hyprland" ];

      input = {
        kb_layout = "us";
        numlock_by_default = true;
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          "tap-to-click" = true;
          disable_while_typing = true;
        };
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(8f00ffee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 5;
          passes = 1;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle.preserve_split = true;
      master.new_status = "master";
      misc.disable_hyprland_logo = true;

      windowrule = [
        "match:title ^(kitty)$, float on"
        "match:title ^(thunar)$, opacity 0.85 override 0.85 override"
        "match:title ^(gedit)$, opacity 0.85 override 0.85 override"
        "match:title ^(catfish)$, opacity 0.85 override 0.85 override"
        "match:title ^(wofi)$, stay_focused on"
        "match:float true, opacity 0.85 0.85"
      ];

      layerrule = [
        "blur on, match:namespace waybar"
        "ignore_alpha 0, match:namespace waybar"
        "blur on, match:namespace wofi"
        "blur on, match:namespace gtk-layer-shell"
      ];

      bind =
        [
          "SUPER, RETURN, exec, kitty -o 'font_size=13' --title ok_its_kitty"
          "CTRLALT, T, exec, kitty -o 'font_size=13' --title ok_its_kitty"
          "SUPER, T, exec, kitty --start-as=fullscreen -o 'font_size=18' --title all_is_kitty"
          "SUPER, I, exec, kitty --title ok_its_kitty --hold nmtui"

          "$mainMod SHIFT, R, exec, hyprctl reload"
          "$mainMod, Q, killactive,"
          "$mainMod SHIFT, E, exec, nwgbar"
          "$mainMod, N, exec, thunar"
          "$mainMod SHIFT, 65, togglefloating,"
          "$mainMod SHIFT, D, exec, nwg-drawer -mb 10 -mr 10 -ml 10 -mt 10"
          "$mainMod, P, pseudo,"
          "$mainMod SHIFT, P, layoutmsg, togglesplit"

          # Function-key app row (Garuda-only apps swapped for NixOS equivalents
          # in configuration.nix's systemPackages — see comment there)
          "$mainMod, F1, exec, firefox"
          "$mainMod, F2, exec, thunderbird"
          "$mainMod, F3, exec, thunar"
          "$mainMod, F4, exec, geany"
          "$mainMod, F5, exec, gitkraken"
          "$mainMod, F6, exec, gparted"
          "$mainMod, F7, exec, inkscape"
          "$mainMod, F8, exec, blender"
          "$mainMod, F9, exec, meld"
          "$mainMod, F10, exec, joplin-desktop"
          "$mainMod, F12, exec, galculator"

          "$mainMod, left, movefocus, l"
          "$mainMod, H, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, L, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, K, movefocus, u"
          "$mainMod, down, movefocus, d"
          "$mainMod, J, movefocus, d"
        ]
        ++ (map (n: "$mainMod, ${toString (lib.mod n 10)}, workspace, ${toString n}") (lib.range 1 10))
        ++ (map (n: "ALT SHIFT, ${toString (lib.mod n 10)}, movetoworkspace, ${toString n}") (lib.range 1 10))
        ++ (map (n: "$mainMod SHIFT, ${toString (lib.mod n 10)}, movetoworkspacesilent, ${toString n}") (lib.range 1 10))
        ++ [
          "$mainMod, S, swapactiveworkspaces, eDP-2 DP-3"
          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up, workspace, e-1"

          "$mainMod, O, exec, firefox"
          "$mainMod, M, fullscreen, 1"
          "$mainMod, F, fullscreen, 0"
          "$mainMod SHIFT, F, fullscreenstate, 0 2"
          "$mainMod SHIFT, C, exec, killall -9 wpaperd && wpaperd"
          "SUPER, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"

          # Screenshots (grim/slurp/swappy, matching the ported scripts below)
          ", Print, exec, grim -g \"$(slurp)\" - | swappy -f -"
          "CTRL, Print, exec, ~/.config/hypr/scripts/screenshot_window.sh"
          "SHIFT, Print, exec, ~/.config/hypr/scripts/screenshot_display.sh"
          "$mainMod, Print, exec, mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png && notify-send 'Screenshot saved' -t 1500"

          "$mainMod, R, submap, resize"
        ];

      bindr = [
        "SUPER, SUPER_L, exec, pkill wofi || wofi --normal-window --show drun --allow-images"
      ];

      binde = [
        # laptop media/volume/brightness keys
        ",122, exec, pamixer --decrease 5; notify-send ' Volume: '$(pamixer --get-volume) -t 500"
        ",123, exec, pamixer --increase 5; notify-send ' Volume: '$(pamixer --get-volume) -t 500"
        ",121, exec, pamixer --toggle-mute; notify-send ' Volume: Toggle-mute' -t 500"
        ",XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle; notify-send 'System Mic: Toggle-mute' -t 500"
        ",232, exec, brightnessctl -c backlight set 5%-"
        ",233, exec, brightnessctl -c backlight set +5%"
        ",172, exec, playerctl play-pause"
        ",171, exec, playerctl next"
        ",173, exec, playerctl previous"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };

    # The resize submap doesn't map cleanly onto a flat settings attrset
    # (it reuses the `submap` key twice with different meaning), so it's
    # carried over verbatim as raw hyprland.conf text.
    extraConfig = ''
      submap=resize
      binde=,right,resizeactive,50 0
      binde=,L,resizeactive,50 0
      binde=,left,resizeactive,-50 0
      binde=,H,resizeactive,-50 0
      binde=,up,resizeactive,0 -50
      binde=,K,resizeactive,0 -50
      binde=,down,resizeactive,0 50
      binde=,J,resizeactive,0 50
      bind=,escape,submap,reset
      submap=reset
    '';
  };

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
          timeout = 300;
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

  # Ported helper scripts referenced by the binds above.
  xdg.configFile."hypr/scripts/idle_inhibitor.sh" = {
    source = ../../dotfiles/hypr/scripts/idle_inhibitor.sh;
    executable = true;
  };
  xdg.configFile."hypr/scripts/screenshot_display.sh" = {
    source = ../../dotfiles/hypr/scripts/screenshot_display.sh;
    executable = true;
  };
  xdg.configFile."hypr/scripts/screenshot_window.sh" = {
    source = ../../dotfiles/hypr/scripts/screenshot_window.sh;
    executable = true;
  };

  ####################################################################
  # Waybar — ported from garuda-hyprland-config/dotconfig/waybar/{config,style.css}
  ####################################################################
  programs.waybar = {
    # Disabled: this wrote ~/.config/waybar/config (stale settings), which waybar
    # loads BEFORE our config.jsonc — shadowing the real bar (lost icons/modules).
    # The real bar is hand-placed at ~/.config/waybar (moving to a stow repo).
    enable = false;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        margin = "0 0 0 0";
        spacing = 0;
        modules-left = [ "custom/launcher" "hyprland/workspaces" "hyprland/window" ];
        modules-center = [ "custom/network_traffic" ];
        modules-right = [
          "clock#time" "custom/updates" "backlight" "custom/keyboard-layout"
          "temperature" "cpu" "memory" "battery" "pulseaudio" "network"
          "tray" "idle_inhibitor" "custom/power"
        ];

        "hyprland/workspaces" = {
          format = "{icon}";
          on-click = "activate";
          all-outputs = true;
          sort-by-number = true;
          format-icons = {
            "1" = "1"; "2" = "2"; "3" = "3"; "4" = "4"; "5" = "5";
            "6" = "6"; "7" = "7"; "8" = "8"; "9" = "9"; "10" = "10";
            focused = ""; default = "";
          };
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
        };
        "hyprland/window" = { format = "{}"; icon = true; icon-size = 20; };
        idle_inhibitor = {
          format = "{icon}";
          format-icons = { activated = ""; deactivated = ""; };
          on-click = "exec ~/.config/hypr/scripts/idle_inhibitor.sh";
        };
        "clock#time" = { format = "  {:%a %d   %H:%M}"; interval = 60; locale = "en_US.UTF-8"; };
        tray = { icon-size = 20; spacing = 4; };
        cpu = { format = "🖳{usage}%"; on-click = "foot -e htop"; };
        memory = { format = "🖴 {: >3}%"; on-click = "foot -e htop"; };
        backlight = {
          format = "{icon} {percent: >3}%";
          format-icons = [ "" "" ];
          on-scroll-down = "brightnessctl -c backlight set 1%-";
          on-scroll-up = "brightnessctl -c backlight set +1%";
          on-click = "~/.config/waybar/scripts/backlight-hint.sh";
        };
        battery = {
          states = { warning = 30; critical = 15; };
          format = "{icon} {capacity: >3}%";
          format-icons = [ "" "" "" "" "" ];
        };
        network = {
          format = "⚠Disabled";
          format-wifi = "";
          format-ethernet = "";
          format-linked = "{ifname} (No IP)";
          format-disconnected = "⚠Disabled";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
          family = "ipv4";
          tooltip-format-wifi = "  {ifname} @ {essid}\nIP: {ipaddr}\nStrength: {signalStrength}%\nFreq: {frequency}MHz\nUp: {bandwidthUpBits} Down: {bandwidthDownBits}";
          tooltip-format-ethernet = " {ifname}\nIP: {ipaddr}\n up: {bandwidthUpBits} down: {bandwidthDownBits}";
          on-click = "nm-connection-editor";
        };
        "custom/power" = { format = "⏻"; on-click = "nwgbar"; tooltip = false; };
        "custom/keyboard-layout" = { format = " Cheat"; on-click = "~/.config/waybar/scripts/keyhint.sh"; };
        "custom/launcher" = {
          format = "    ";
          on-click = "exec nwg-drawer -c 7 -is 70 -spacing 23";
          tooltip = false;
        };
        "custom/network_traffic" = {
          exec = "~/.config/waybar/scripts/network_traffic.sh";
          return-type = "json";
          format-ethernet = "{icon} {ifname} ⇣{bandwidthDownBytes} ⇡{bandwidthUpBytes}";
        };
        pulseaudio = {
          scroll-step = 3;
          format = "{icon} {volume}% {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = "";
          format-source-muted = "";
          format-icons = {
            headphone = ""; hands-free = ""; headset = ""; phone = "";
            portable = ""; car = ""; default = [ "" "" "" ];
          };
          on-click = "footclient -T waybar_alsamixer -e alsamixer -M";
          on-click-right = "pavucontrol";
        };
      };
    };
    style = builtins.readFile ../../dotfiles/waybar/style.css;
  };

  xdg.configFile."waybar/scripts" = {
    source = ../../dotfiles/waybar/scripts;
    recursive = true;
  };
  home.activation.makeWaybarScriptsExecutable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    chmod +x $HOME/.config/waybar/scripts/* 2>/dev/null || true
  '';

  ####################################################################
  # wofi — ported from garuda-hyprland-config/dotconfig/wofi/{config,style.css}
  ####################################################################
  programs.wofi = {
    enable = true;
    settings = {
      location = "middle";
      show = "drun";
      width = 650;
      height = 550;
      always_parse_args = true;
      show_all = true;
      print_command = true;
      layer = "overlay";
      insensitive = true;
      prompt = "";
    };
    style = builtins.readFile ../../dotfiles/wofi/style.css;
  };

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

  programs.starship = {
    enable = true;
    settings = {
      username = {
        format = " [╭─$user]($style)@";
        show_always = true;
        style_root = "bold red";
        style_user = "bold red";
      };
      hostname = {
        disabled = false;
        format = "[$hostname]($style) in ";
        ssh_only = false;
        style = "bold dimmed red";
        trim_at = "-";
      };
      directory = {
        style = "purple";
        truncate_to_repo = true;
        truncation_length = 0;
        truncation_symbol = "repo: ";
      };
      sudo.disabled = false;
      git_status = {
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        deleted = "x";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        style = "white";
      };
      cmd_duration = {
        disabled = false;
        format = "took [$duration]($style)";
        min_time = 1;
      };
      character = {
        error_symbol = " [×](bold red)";
        success_symbol = " [╰─λ](bold red)";
      };
      nix_shell.symbol = " ";
      git_branch.symbol = " ";
      rust.symbol = " ";
      nodejs.symbol = " ";
      python.symbol = " ";
      docker_context.symbol = " ";
    };
  };

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
