{ lib
, stdenvNoCC
, makeWrapper
, writeShellScript
, src
, pythonEnv
, ydotool
, wl-clipboard
, libnotify
, pulseaudio
, xdotool
, wtype
, glib
, gtk4
, gdk-pixbuf
, pango
, graphene
, gtk4-layer-shell
, harfbuzz
, cairo
, gobject-introspection
}:

let
  # install_backend()/setup_python_venv() in backend_installer.py hand back a
  # "pip binary" to run `pip install ...` against. Under HYPRWHSPR_NIX_MANAGED
  # the real work (pywhispercpp, onnx-asr, cloud-backend deps) is already done
  # by pythonEnv, so this shim just needs to make any leftover "pip install"
  # call a harmless no-op instead of failing to write into the store.
  nixPipShim = writeShellScript "hyprwhspr-nix-pip-shim" ''
    echo "[nix] skipping 'pip $*' - dependencies are provided by the Nix package" >&2
    exit 0
  '';

  giTypelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    glib.out gtk4 gdk-pixbuf pango.out graphene gtk4-layer-shell harfbuzz
    # Gtk-4.0's GIR references cairo types; cairo itself doesn't build
    # introspection data, gobject-introspection ships a hand-written
    # cairo-1.0.typelib for exactly this reason.
    gobject-introspection
  ];
  gtkLibPath = lib.makeLibraryPath [
    glib gtk4 gdk-pixbuf pango graphene gtk4-layer-shell harfbuzz cairo
  ];

  runtimeBinPath = lib.makeBinPath [
    ydotool wl-clipboard libnotify pulseaudio xdotool wtype
  ];
in
stdenvNoCC.mkDerivation {
  pname = "hyprwhspr";
  version = "0-unstable";

  inherit src;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r bin lib share config docs $out/
    cp requirements.txt requirements-visualizer.txt LICENSE README.md $out/

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/hyprwhspr \
      --set HYPRWHSPR_NIX_PYTHON "${pythonEnv}/bin/python3" \
      --set HYPRWHSPR_NIX_MANAGED "1" \
      --set HYPRWHSPR_NIX_PIP_SHIM "${nixPipShim}" \
      --prefix PATH : "${runtimeBinPath}" \
      --prefix GI_TYPELIB_PATH : "${giTypelibPath}" \
      --prefix LD_LIBRARY_PATH : "${gtkLibPath}"
  '';

  # bin/meeting-recorder and config/hyprland/hyprwhspr-tray.sh shell out to the
  # `hyprwhspr` CLI by name (via PATH) rather than an absolute path, so give
  # them the same treatment.
  postInstall = ''
    for f in $out/bin/meeting-recorder $out/config/hyprland/hyprwhspr-tray.sh; do
      [ -e "$f" ] && chmod +x "$f"
    done
  '';

  meta = with lib; {
    description = "Native speech-to-text for Linux (Nix package)";
    homepage = "https://github.com/goodroot/hyprwhspr";
    license = licenses.mit;
    mainProgram = "hyprwhspr";
    platforms = platforms.linux;
  };
}
