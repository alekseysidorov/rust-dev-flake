{
  lib,
  fetchCrate,
  pkg-config,
  udev,
  fontconfig,
  stdenv,

  rust-bin,
  makeRustPlatform,
}:
let
  rust = rust-bin.stable."1.97.1".minimal;

  rustPlatform = makeRustPlatform {
    cargo = rust;
    rustc = rust;
  };
in

rustPlatform.buildRustPackage rec {
  pname = "comchan";
  version = "0.14.0";
  strictDeps = true;

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-7O3ETjsm5k5lU/wCcpCRR6EVie+UrFzWQSjp0d+f+n4=";
  };

  cargoHash = "sha256-lRVP1vkY2pVr9aH/Q8wYVi/gzD4IBSKw42kUaV3ZjAE=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    udev
    fontconfig
  ];

  meta = with lib; {
    description = "A blazingly fast and minimal serial monitor for embedded applications";
    homepage = "https://github.com/Vaishnav-Sabari-Girish/ComChan";
    license = licenses.mit;
    mainProgram = "comchan";
    maintainers = with lib.maintainers; [ alekseysidorov ];
    platforms = platforms.unix;
  };
}
