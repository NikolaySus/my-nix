{
  # These non-secret identifiers are also applied by scripts/install-t7.sh.
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-uuid/4505e5ba-379c-4c90-a0d7-10586dfe84ef";
    allowDiscards = false;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/e3f960b7-e183-4fa8-948e-e3e555a75f56";
      fsType = "btrfs";
      options = [
        "subvol=@root"
        "compress=zstd:3"
        "noatime"
      ];
    };

    "/home" = {
      device = "/dev/disk/by-uuid/e3f960b7-e183-4fa8-948e-e3e555a75f56";
      fsType = "btrfs";
      options = [
        "subvol=@home"
        "compress=zstd:3"
        "noatime"
      ];
    };

    "/nix" = {
      device = "/dev/disk/by-uuid/e3f960b7-e183-4fa8-948e-e3e555a75f56";
      fsType = "btrfs";
      neededForBoot = true;
      options = [
        "subvol=@nix"
        "compress=zstd:3"
        "noatime"
      ];
    };

    "/var/log" = {
      device = "/dev/disk/by-uuid/e3f960b7-e183-4fa8-948e-e3e555a75f56";
      fsType = "btrfs";
      neededForBoot = true;
      options = [
        "subvol=@log"
        "compress=zstd:3"
        "noatime"
      ];
    };

    "/.snapshots" = {
      device = "/dev/disk/by-uuid/e3f960b7-e183-4fa8-948e-e3e555a75f56";
      fsType = "btrfs";
      options = [
        "subvol=@snapshots-root"
        "compress=zstd:3"
        "noatime"
      ];
    };

    "/home/.snapshots" = {
      device = "/dev/disk/by-uuid/e3f960b7-e183-4fa8-948e-e3e555a75f56";
      fsType = "btrfs";
      options = [
        "subvol=@snapshots-home"
        "compress=zstd:3"
        "noatime"
      ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/0D08-E253";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };
}
