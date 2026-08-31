{ ... }:
{
  boot = {
    loader = {
      timeout = 8;
      efi = {
        canTouchEfiVariables = false;
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        devices = [ "nodev" ];
        efiSupport = true;
        efiInstallAsRemovable = true;
        configurationLimit = 10;
        useOSProber = false;
      };
    };

    initrd.availableKernelModules = [
      "ahci"
      "ehci_pci"
      "nvme"
      "sd_mod"
      "uas"
      "usb_storage"
      "usbhid"
      "xhci_pci"
    ];
  };
}
