{ ... }:
{
  imports = [
    ./storage.nix
    ../../modules/boot.nix
    ../../modules/hardware.nix
    ../../modules/networking.nix
    ../../modules/desktop.nix
    ../../modules/system.nix
  ];

  networking.hostName = "portable";

  users.mutableUsers = true;
  users.users = {
    root.hashedPassword = "!";
    nop = {
      isNormalUser = true;
      uid = 1000;
      description = "nop";
      extraGroups = [
        "audio"
        "input"
        "networkmanager"
        "video"
        "wheel"
      ];
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.nop = import ../../home/nop;
  };

  system.stateVersion = "26.05";
}
