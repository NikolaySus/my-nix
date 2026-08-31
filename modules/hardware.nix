{ config, lib, ... }:
{
  nixpkgs.config.allowUnfree = true;

  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
    cpu.intel.updateMicrocode = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  services.fwupd.enable = true;

  specialisation.nvidia.configuration = {
    system.nixos.tags = [ "nvidia" ];
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  assertions = [
    {
      assertion = lib.versionAtLeast config.system.nixos.release "26.05";
      message = "This configuration expects NixOS 26.05 or newer.";
    }
  ];
}
