{
  description = "mps NixOS + Hyprland system config (successor to garuda-hyprland-config)";

  inputs = {
    # Pin to the current NixOS stable release (26.05, per nixos.org/download).
    # 26.05 IS the newest release — checked 2026-10-01, nixpkgs has no
    # nixos-26.11 branch yet (releases are cut on a May/November cadence, so
    # 26.11 lands ~end of November). Bumping this input is therefore a
    # backport bump, not a version upgrade.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # The rolling channel, deliberately NOT this system's base. It is reachable
    # only as `pkgs.unstable.*`, through the overlay in configuration.nix, so
    # individual fast-moving user-space tools can run ahead of stable while the
    # kernel, the NVIDIA driver, and the 32-bit gaming stack stay on tested
    # 26.05 — the three things whose breakage costs a boot rather than a retry.
    #
    # Cost of each package taken from here: unstable's glibc is not 26.05's, so
    # an overlaid package drags its own slice of unstable's closure. Nix handles
    # that correctly; it is disk and download, not breakage. Which is why the
    # cherry-picks are a short list of things whose version actually matters,
    # not a blanket redirect.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning, used only at install time.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen Browser isn't in nixpkgs proper yet; this community flake is the
    # one linked from the official NixOS wiki's Zen Browser page.
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative KDE Plasma settings — used here to default Plasma to a dark
    # color scheme. Home-Manager module, wired via sharedModules below.
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Hunk — terminal diff viewer. Not in nixpkgs; ships its own flake. NOT
    # following our nixpkgs (its bun2nix build wants its own pin), which just
    # means a second nixpkgs entry in flake.lock — harmless.
    hunk.url = "github:modem-dev/hunk";
  };

  outputs = { self, nixpkgs, home-manager, disko, ... }@inputs:
    {
      # No `system` argument here on purpose: the platform is declared by the
      # host itself, as `nixpkgs.hostPlatform` in configuration.nix. Passing
      # `system` to nixosSystem is the older idiom and is what populates the
      # deprecated `pkgs.system`, the warning silenced in c8e9073. Keeping the
      # platform next to the hardware it describes also means a second host
      # can differ without touching this file.
      nixosConfigurations.hypr-nix = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          # disko.nixosModules.disko and disko-config.nix are deliberately
          # NOT imported here: the laptop's disk is already partitioned
          # (vanilla installer already ran), and its real
          # hardware-configuration.nix already declares the correct
          # fileSystems — importing disko's own guess on top would
          # conflict with that. Re-add both if this host is ever
          # reinstalled from scratch onto a blank disk.
          ./hosts/hypr-nix/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Make the plasma-manager module available inside home.nix.
            home-manager.sharedModules = [ inputs.plasma-manager.homeModules.plasma-manager ];
            home-manager.users.mps = import ./home/mps/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };
    };
}
