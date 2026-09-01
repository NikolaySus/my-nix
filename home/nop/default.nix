{ pkgs, ... }:
let
  yufi = pkgs.callPackage ../../packages/yufi.nix { };
  autoOutputScale = pkgs.writeShellApplication {
    name = "auto-output-scale";
    runtimeInputs = with pkgs; [
      jq
      wlr-randr
    ];
    text = ''
      while IFS=$'\t' read -r output height current_scale; do
        if ((height <= 1600)); then
          target_scale="1"
        elif ((height <= 2400)); then
          target_scale="1.5"
        elif ((height <= 3200)); then
          target_scale="2"
        else
          target_scale="3"
        fi

        if [[ "$current_scale" != "$target_scale" ]]; then
          wlr-randr --output "$output" --scale "$target_scale"
        fi
      done < <(
        wlr-randr --json | jq -r '
          .[]
          | select(.enabled)
          | (.modes[] | select(.current)) as $mode
          | [.name, $mode.height, .scale]
          | @tsv
        '
      )
    '';
  };
in
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
      pavucontrol
      ripgrep
      rsync
      tree
      telegram-desktop
      unzip
      wget
      yufi
      zip
    ];
  };

  programs.home-manager.enable = true;

  gtk = {
    enable = true;
    colorScheme = "dark";
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
    icon-theme = "Adwaita";
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

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
        format-wifi = "󰖩  {essid} {signalStrength}%";
        format-ethernet = "󰈀  {ipaddr}/{cidr}";
        format-disconnected = "󰖪  offline";
        tooltip-format = "{ifname}: {ipaddr}/{cidr}";
        tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ifname}: {ipaddr}/{cidr}";
        tooltip-format-disconnected = "Network disconnected";
        on-click = "${yufi}/bin/yufi";
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

  services.kanshi.enable = true;

  xdg.configFile = {
    "driftwm/config.toml".source = ./driftwm/config.toml;
    "kanshi/config".text = ''
      profile auto-scale {
        ...output "*" mode preferred
        exec ${autoOutputScale}/bin/auto-output-scale
      }
    '';
    "xfce4/helpers.rc".text = ''
      TerminalEmulator=foot
    '';
  };
}
