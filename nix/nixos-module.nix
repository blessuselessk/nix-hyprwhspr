{ config, lib, ... }:

let
  cfg = config.programs.hyprwhspr;
in
{
  options.programs.hyprwhspr = {
    enable = lib.mkEnableOption ''
      system prerequisites hyprwhspr needs: the uinput kernel module/device
      (for its evdev-based global hotkeys and text injection - see
      lib/src/global_shortcuts.py) and group membership for the users who run
      it. This does not install hyprwhspr itself - use the flake's home-manager
      module (or `home.packages`/`environment.systemPackages`) for that.
    '';

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Users to add to the `uinput` group, so hyprwhspr can open
        /dev/uinput to create its virtual keyboard for hotkeys and text
        injection, and the `input` group for reading raw keyboard events.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.uinput.enable = true;

    users.users = lib.genAttrs cfg.users (_: {
      extraGroups = [ "uinput" "input" ];
    });
  };
}
