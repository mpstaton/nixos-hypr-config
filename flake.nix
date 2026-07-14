{
  description = "mps NixOS + Hyprland system config (successor to garuda-hyprland-config)";

  inputs = {
    # Pin to the current NixOS stable release (26.05, per nixos.org/download).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

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
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.hypr-nix = nixpkgs.lib.nixosSystem {
        inherit system;
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
