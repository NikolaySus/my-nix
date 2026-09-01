{
  config,
  lib,
  pkgs,
  ...
}:
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

  # This profile is intentionally machine-specific. The PCI bus IDs match the
  # Intel Raptor Lake-P iGPU and RTX 4060 in the current ASUS laptop.
  specialisation.nvidia-intel-offload.configuration = {
    system.nixos.tags = [ "nvidia-intel-offload" ];

    services.xserver.videoDrivers = [
      "modesetting"
      "nvidia"
    ];

    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      powerManagement.finegrained = true;

      prime = {
        intelBusId = "PCI:0@0:2:0";
        nvidiaBusId = "PCI:1@0:0:0";
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      };
    };

    programs = {
      gamemode.enable = true;
      steam.enable = true;
    };

    environment.systemPackages = with pkgs; [
      cudaPackages.cudatoolkit
      mangohud
      mesa-demos
      nvtopPackages.nvidia
      vulkan-tools
    ];
  };

  assertions = [
    {
      assertion = lib.versionAtLeast config.system.nixos.release "26.05";
      message = "This configuration expects NixOS 26.05 or newer.";
    }
  ];
}
