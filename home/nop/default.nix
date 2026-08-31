{ pkgs, ... }:
{
  home = {
    username = "nop";
    homeDirectory = "/home/nop";
    stateVersion = "26.05";
    sessionVariables = {
      BROWSER = "firefox";
      EDITOR = "nvim";
      LAUNCHER = "fuzzel";
      TERMINAL = "foot";
    };
    packages = with pkgs; [
      blueman
      codex
      curl
      file
      firefox
      jq
      lxqt.lxqt-policykit
      networkmanagerapplet
      pavucontrol
      ripgrep
      rsync
      tree
      telegram-desktop
      unzip
      wget
      zip
    ];
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      include.path = "~/.gitconfig.local";
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.foot = {
    enable = true;
    settings = {
      main.font = "JetBrainsMono Nerd Font:size=11";
      scrollback.lines = 10000;
    };
  };

  programs.fuzzel = {
    enable = true;
    settings.main = {
      terminal = "foot";
      layer = "overlay";
      width = 50;
    };
  };

  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = [ "wlr/taskbar" ];
      modules-center = [ "clock" ];
      modules-right = [
        "network"
        "pulseaudio"
        "battery"
        "tray"
      ];
      clock.format = "{:%a %Y-%m-%d %H:%M}";
      network = {
        format-wifi = "{essid} {signalStrength}%";
        format-ethernet = "{ipaddr}/{cidr}";
        format-disconnected = "offline";
      };
      pulseaudio = {
        format = "vol {volume}%";
        format-muted = "muted";
      };
      battery = {
        format = "bat {capacity}%";
        format-charging = "chg {capacity}%";
      };
    };
    style = ''
      * { font-family: "JetBrainsMono Nerd Font"; font-size: 12px; }
      window#waybar { background: rgba(25, 25, 30, 0.92); color: #eeeeee; }
      #taskbar, #clock, #network, #pulseaudio, #battery, #tray { padding: 0 8px; }
    '';
  };

  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      border-radius = 6;
      border-size = 2;
    };
  };

  xdg.configFile = {
    "driftwm/config.toml".source = ./driftwm/config.toml;
    "xfce4/helpers.rc".text = ''
      TerminalEmulator=foot
    '';
  };
}
