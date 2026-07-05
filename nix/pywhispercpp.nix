{ lib
, buildPythonPackage
, fetchgit
, cmake
, ninja
, setuptools
, setuptools-scm
, wheel
, numpy
, sounddevice
, webrtcvad
, requests
, tqdm
, platformdirs
}:

# hyprwhspr's local Whisper backend is pywhispercpp (in-process bindings for
# whisper.cpp), pinned to a specific upstream commit. It isn't in nixpkgs, so
# we build it here from source instead of relying on upstream's prebuilt
# manylinux wheels (which assume a glibc/FHS layout hyprwhspr's own installer
# downloads at runtime - not something that fits a Nix store closure).
buildPythonPackage rec {
  pname = "pywhispercpp";
  version = "1.5.0";
  pyproject = true;

  src = fetchgit {
    url = "https://github.com/Absadiki/pywhispercpp.git";
    rev = "294e1e15f1fa3991aaa8db5f5e9afb97ade5ba5f";
    fetchSubmodules = true;
    hash = "sha256-sya7mAz8hrLarS+lqe+ObHN/boahJb3pfwDaWU0+ZlM=";
  };

  # setup.py drives its own CMake configure/build (whisper.cpp is vendored as
  # a submodule); the CMake build hooks that ordinarily run standalone would
  # only fight with it.
  dontUseCmakeConfigure = true;

  # pyproject.toml also lists "repairwheel" under [build-system].requires,
  # but it's only ever invoked (as an external command, not an import) from a
  # bdist_wheel subclass that repairwheel's setup.py restricts to `win32`, so
  # it does nothing on Linux. There's no nixpkgs package for it - drop it
  # rather than packaging a tool that never runs here.
  postPatch = ''
    sed -i '/"repairwheel"/d' pyproject.toml
  '';

  nativeBuildInputs = [ cmake ninja setuptools setuptools-scm wheel ];

  # No git metadata in the store path for setuptools-scm to read a version from.
  SETUPTOOLS_SCM_PRETEND_VERSION = version;

  # Build a portable binary rather than tuning for the machine doing the
  # build - important since this is meant to be shared/cached. RPATH must be
  # set at link time ($ORIGIN, so _pywhispercpp's .so finds libwhisper/libggml
  # sitting next to it in site-packages) because setup.py only does this
  # itself in editable-mode builds; a normal build otherwise ships the
  # absolute /build/... rpath CMake used while compiling, which nixpkgs'
  # fixup phase rightly refuses to let into the store.
  CMAKE_ARGS = "-DGGML_NATIVE=OFF -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DCMAKE_INSTALL_RPATH=$ORIGIN";

  dependencies = [
    numpy
    sounddevice
    webrtcvad
    requests
    tqdm
    platformdirs
  ];

  pythonImportsCheck = [ "pywhispercpp" ];

  meta = with lib; {
    description = "Python bindings for whisper.cpp, pinned to the commit hyprwhspr builds against";
    homepage = "https://github.com/Absadiki/pywhispercpp";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
