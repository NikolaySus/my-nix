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
      rog-control-center = {
        enable = true;
        # NixOS 26.11 still expects the pre-6.4 desktop filename when
        # generating autostart entries, so install the renamed file below.
        autoStart = false;
      };
      steam.enable = true;
    };

    environment.systemPackages = with pkgs; [
      cudaPackages.cudatoolkit
      glmark2
      mangohud
      mesa-demos
      nvtopPackages.nvidia
      vulkan-tools
    ];

    environment.etc."xdg/autostart/org.opengamingcollective.rog-control-center.desktop".source =
      "${pkgs.asusctl}/share/applications/org.opengamingcollective.rog-control-center.desktop";
  };

  assertions = [
    {
      assertion = lib.versionAtLeast config.system.nixos.release "26.05";
      message = "This configuration expects NixOS 26.05 or newer.";
    }
  ];
}
