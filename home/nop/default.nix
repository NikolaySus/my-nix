{ lib, pkgs, ... }:
let
  yufi = pkgs.callPackage ../../packages/yufi.nix { };
  bluetoothPairByName = pkgs.writeShellApplication {
    name = "bluetooth-pair-by-name";
    runtimeInputs = with pkgs; [ bluez ];
    text = builtins.readFile ../../scripts/bluetooth-pair-by-name.sh;
  };
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
      bluetoothPairByName
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
      colors-dark = {
        background = "19191e";
        alpha = 0.85;
      };
    };
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "foot";
        layer = "overlay";
        width = 50;
      };
      colors.background = "19191ed9";
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
      window#waybar { background: rgba(25, 25, 30, 0.85); color: #eeeeee; }
      #taskbar, #clock, #network, #pulseaudio, #battery, #tray { padding: 0 8px; }
    '';
  };

  services.mako = {
    enable = true;
    settings = {
      background-color = "#19191ED9";
      default-timeout = 5000;
      border-radius = 6;
      border-size = 2;
    };
  };

  services.kanshi.enable = true;

  home.activation.clashVergeTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    verge_config="/home/nop/.local/share/io.github.clash-verge-rev.clash-verge-rev/verge.yaml"
    theme_css="/home/nop/.config/clash-verge/theme.css"

    if [[ -f "$verge_config" ]]; then
      run ${pkgs.yq-go}/bin/yq --inplace \
        '.theme_mode = "dark" | .theme_setting = (.theme_setting // {}) | .theme_setting.css_injection = load_str("'"$theme_css"'")' \
        "$verge_config"
    fi
  '';

  xdg.configFile = {
    "clash-verge/theme.css".text = ''
      /* Keep the palette in sync with the rest of the desktop. */
      :root {
        color-scheme: dark;
        --desktop-surface: #19191e;
        --desktop-surface-hover: #24242b;
        --desktop-text: #eeeeee;
        --desktop-text-secondary: #b8b8c0;
      }

      html,
      body,
      #root {
        background-color: var(--desktop-surface) !important;
        color: var(--desktop-text) !important;
      }

      /* Clash Verge uses Material UI for cards, navigation and overlays. */
      .MuiPaper-root,
      .MuiCard-root,
      .MuiAppBar-root,
      .MuiDrawer-paper {
        background-color: var(--desktop-surface) !important;
        background-image: none !important;
      }

      /* Floating content should remain easy to read over the main window. */
      .MuiDialog-paper,
      .MuiMenu-paper,
      .MuiPopover-paper,
      .MuiTooltip-tooltip,
      .MuiSnackbarContent-root {
        background-color: var(--desktop-surface-hover) !important;
        color: var(--desktop-text) !important;
      }

      .MuiTypography-colorTextSecondary,
      .MuiListItemText-secondary,
      .MuiFormHelperText-root {
        color: var(--desktop-text-secondary) !important;
      }

      .MuiButtonBase-root:hover,
      .MuiListItemButton-root:hover,
      .MuiMenuItem-root:hover,
      .MuiTab-root:hover,
      .MuiTableRow-hover:hover {
        background-color: var(--desktop-surface-hover) !important;
      }
    '';
    "driftwm/config.toml".source = ./driftwm/config.toml;
    "driftwm/shaders/glslsandbox-108166.glsl".source = ./driftwm/shaders/glslsandbox-108166.glsl;
    "gtk-3.0/gtk.css".text = ''
      /* Draw alpha once at the window root; content views reveal that layer. */
      window.background,
      window.background:backdrop {
        background-color: rgba(25, 25, 30, 0.85);
      }

      .view,
      .view:backdrop,
      .sidebar,
      .sidebar:backdrop,
      iconview,
      iconview:backdrop,
      treeview.view,
      treeview.view:backdrop,
      notebook > stack,
      notebook > stack:backdrop,
      viewport,
      viewport:backdrop,
      textview text,
      textview text:backdrop {
        background-color: transparent;
        background-image: none;
      }

      .sidebar row:hover:not(:selected),
      treeview.view:hover:not(:selected),
      notebook > header > tabs > tab:hover:not(:checked),
      menu menuitem:hover,
      popover modelbutton:hover,
      combobox window.popup treeview.view:hover:not(:selected) {
        background-color: rgba(25, 25, 30, 0.95);
      }
    '';
    "gtk-4.0/gtk.css".text = ''
      /* GTK4 equivalents for YuFi, Wdisplays, and portal dialogs. */
      window.background,
      window.background:backdrop {
        background-color: rgba(25, 25, 30, 0.85);
      }

      .view,
      .view:backdrop,
      .sidebar,
      .sidebar:backdrop,
      listview,
      listview:backdrop,
      gridview,
      gridview:backdrop,
      columnview,
      columnview:backdrop,
      notebook > stack,
      notebook > stack:backdrop,
      viewport,
      viewport:backdrop,
      textview text,
      textview text:backdrop {
        background-color: transparent;
        background-image: none;
      }

      .sidebar row:hover:not(:selected),
      listview > row:hover:not(:selected),
      gridview > child:hover:not(:selected),
      columnview row:hover:not(:selected),
      notebook > header > tabs > tab:hover:not(:checked),
      popover contents row:hover:not(:selected),
      popover modelbutton:hover,
      dropdown > popover listview > row:hover:not(:selected) {
        background-color: rgba(25, 25, 30, 0.95);
      }
    '';
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
