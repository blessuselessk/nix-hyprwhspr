{ config, lib, pkgs, ... }:

let
  cfg = config.services.hyprwhspr;
  jsonFormat = pkgs.formats.json { };
in
{
  options.services.hyprwhspr = {
    enable = lib.mkEnableOption "hyprwhspr, native speech-to-text for Linux";

    package = lib.mkOption {
      type = lib.types.package;
      example = lib.literalExpression "inputs.nix-hyprwhspr.packages.\${pkgs.system}.default";
      description = ''
        The hyprwhspr package to run. There's no default here on purpose -
        pass the package from this flake for your system, e.g.
        `inputs.nix-hyprwhspr.packages.${pkgs.system}.default`.
      '';
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          backend = "pywhispercpp";
          model = "base.en";
        }
      '';
      description = ''
        hyprwhspr's config.json, as a Nix attrset (see
        share/config.schema.json and docs/CONFIGURATION.md for available
        keys). Written to `$XDG_CONFIG_HOME/hyprwhspr/config.json`.

        Leave this empty (the default) to manage config.json yourself via
        `hyprwhspr config edit` instead - once this option is non-empty,
        Home Manager owns the file and overwrites manual edits on the next
        activation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."hyprwhspr/config.json" = lib.mkIf (cfg.settings != { }) {
      source = jsonFormat.generate "hyprwhspr-config.json" (
        { "$schema" = "https://raw.githubusercontent.com/goodroot/hyprwhspr/main/share/config.schema.json"; }
        // cfg.settings
      );
    };

    # Mirrors config/systemd/hyprwhspr.service, pointed at the Nix store
    # package instead of /usr/lib/hyprwhspr. Bar integration (Waybar/Noctalia)
    # and the Hyprland keybind are left to the CLI (`hyprwhspr waybar`,
    # `hyprwhspr noctalia`, or a manual bind) since those are interactive,
    # one-shot wizards that write into files Home Manager doesn't otherwise
    # own - running them again after a package update is harmless (idempotent).
    systemd.user.services.hyprwhspr = {
      Unit = {
        Description = "hyprwhspr stt";
        Documentation = "https://github.com/goodroot/hyprwhspr";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" "pipewire.service" "wireplumber.service" ];
        Wants = [ "pipewire.service" "wireplumber.service" ];
      };

      Service = {
        Type = "simple";
        ExecStartPre = "${pkgs.writeShellScript "hyprwhspr-wait-for-wayland" ''
          for i in $(seq 1 60); do
            ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1 && exit 0
            sleep 0.25
          done
          echo "Wayland socket not found" >&2
          exit 1
        ''}";
        ExecStart = "${cfg.package}/bin/hyprwhspr";
        ExecStopPost = "${pkgs.writeShellScript "hyprwhspr-stop-cleanup" ''
          pkill -9 -f "hyprwhspr-virtual-keyboard" 2>/dev/null
          pkill -9 -f "hyprwhspr-ydotool.sock" 2>/dev/null
          true
        ''}";
        Restart = "on-failure";
        RestartSec = 2;
        StandardOutput = "journal";
        StandardError = "journal";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
