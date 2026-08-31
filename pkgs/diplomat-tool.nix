{
  lib,
  rustPlatform,
  fetchCrate,
}:

rustPlatform.buildRustPackage rec {
  pname = "diplomat-tool";
  version = "0.16.1";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-+x1uEhnVq/47lTycPtHqE4T0z2dLCpQUWXFdzyLoZQY=";
  };

  cargoHash = "sha256-gdyerVP3mq99MyCe+h4WrCola/xhun/o9K+CCshrVPo=";

  meta = {
    description = "Tool for generating FFI bindings for various languages";
    homepage = "https://github.com/rust-diplomat/diplomat";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "diplomat-tool";
    maintainers = [ lib.maintainers.alekseysidorov ];
  };
}
