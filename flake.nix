{
  description = "Portable encrypted NixOS system for a Samsung T7 Shield";

  inputs = {
    # The official channel CDN is more reliable than GitHub's archive endpoint
    # on the network used to install this machine. flake.lock still makes it
    # immutable until an explicit `nix flake update`.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    driftwm = {
      url = "github:malbiruk/driftwm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    happ-nix = {
      url = "github:DaHL-gh/happ-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      driftwm,
      happ-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.portable = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          driftwm.nixosModules.default
          happ-nix.nixosModules.default
          home-manager.nixosModules.home-manager
          ./hosts/portable
        ];
      };

      checks.${system}.portable = self.nixosConfigurations.portable.config.system.build.toplevel;
      devShells.${system}.installer = pkgs.mkShellNoCC {
        packages = with pkgs; [
          btrfs-progs
          cryptsetup
          dosfstools
          gptfdisk
          gnugrep
          nixos-install-tools
          rsync
          shellcheck
          systemd
          util-linux
        ];
      };
      formatter.${system} = pkgs.nixfmt;
    };
}
