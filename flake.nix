{
  description = "hyprwhspr - native speech-to-text for Linux, packaged for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    (flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        src = self;

        pywhispercpp = pkgs.python3.pkgs.callPackage ./nix/pywhispercpp.nix { };

        # Everything hyprwhspr's local backends (pywhispercpp, onnx-asr) and
        # cloud backends (rest-api, realtime-ws, elevenlabs-realtime) import,
        # plus the optional mic-osd visualizer's GTK4 bindings. See
        # requirements.txt / requirements-visualizer.txt and
        # HYPRWHSPR_NIX_MANAGED in lib/src/backend_installer.py for how this
        # replaces hyprwhspr's own self-managed venv + pip-install-on-setup
        # flow.
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          # Audio processing
          sounddevice
          numpy
          scipy

          # Global shortcuts and text injection
          evdev
          pyperclip

          # Local Whisper backend
          pywhispercpp

          # Local Parakeet TDT backend (CPU-optimized ONNX)
          onnx-asr
          onnxruntime

          # Cloud backends: REST API / realtime WebSocket / ElevenLabs
          requests
          websocket-client
          elevenlabs

          # System integration
          psutil
          pyudev
          pulsectl
          dbus-python

          # CLI formatting and logging
          rich

          # mic-osd visualizer (optional, best-effort upstream too)
          pygobject3
          pycairo
        ]);

        hyprwhspr = pkgs.callPackage ./nix/hyprwhspr.nix {
          inherit src pythonEnv;
        };
      in
      {
        packages = {
          default = hyprwhspr;
          hyprwhspr = hyprwhspr;
          inherit pywhispercpp;
          inherit pythonEnv;
        };

        apps.default = {
          type = "app";
          program = "${hyprwhspr}/bin/hyprwhspr";
          meta.description = "Run hyprwhspr";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pythonEnv
            pkgs.ydotool
            pkgs.wl-clipboard
            pkgs.libnotify
            pkgs.pulseaudio
            pkgs.xdotool
            pkgs.wtype
            pkgs.gtk4-layer-shell
          ];

          shellHook = ''
            export HYPRWHSPR_ROOT="$PWD"
            export PYTHONPATH="$PWD/lib:$PYTHONPATH"
          '';
        };
      })) // {
      # Not per-system: a NixOS module (uinput/group prerequisites) and a
      # home-manager module (package + settings + systemd --user service).
      # See nix/nixos-module.nix and nix/home-manager-module.nix.
      nixosModules.default = import ./nix/nixos-module.nix;
      homeManagerModules.default = import ./nix/home-manager-module.nix;
    };
}
