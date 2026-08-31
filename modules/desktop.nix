{ config, pkgs, ... }:
let
  driftwm = config.programs.driftwm.package;
  sessions = config.services.displayManager.sessionData.desktops;
in
{
  programs.driftwm.enable = true;
  programs.xwayland.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${sessions}/share/wayland-sessions --cmd ${driftwm}/bin/driftwm-session";
      user = "greeter";
    };
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.udisks2.enable = true;

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      adwaita-fonts
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
    ];
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
    grim
    libnotify
    playerctl
    slurp
    swayidle
    swaylock
    wayland-utils
    wdisplays
    wl-clipboard
  ];
}
