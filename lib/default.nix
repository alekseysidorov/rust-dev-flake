# Flake inputs
{ inputs }:
{
  # The calling flake's `self`
  self,
  # Target system architecture
  system,
  # Path to the project root (used for crane source filtering)
  # Defaults to `self`; pass `./.` explicitly if needed
  root ? self,
  # Rust toolchain to use for builds
  toolchain,
  # Build dependencies for the project
  buildInputs ? [ ],
  # Native build dependencies for the project
  nativeBuildInputs ? [ ],
}:

let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  # Crane uses MSRV toolchain to verify minimum version compatibility
  craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;
  # Use project source as-is without filtering
  src = root;
  # Common arguments for all crane builds
  commonArgs = {
    inherit src nativeBuildInputs;
    strictDeps = true;
    cargoVendorDir = craneLib.vendorCargoDeps { inherit src; };
  };
  # Build dependencies only (for caching between checks)
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  # Helper: create a crane check derivation
  # Usage: mkCargoCheck "nextest" "--workspace --all-targets --all-features"
  mkCargoCheck =
    checkType: args:
    let
      checks = {
        nextest = {
          builder = craneLib.cargoNextest;
          argsAttr = "cargoNextestExtraArgs";
        };
        clippy = {
          builder = craneLib.cargoClippy;
          argsAttr = "cargoClippyExtraArgs";
        };
        test = {
          builder = craneLib.cargoTest;
          argsAttr = "cargoTestExtraArgs";
        };
        doc = {
          builder = craneLib.cargoDoc;
          argsAttr = "cargoDocExtraArgs";
        };
      };
      checkConfig = checks.${checkType};
    in
    checkConfig.builder (
      commonArgs // { inherit cargoArtifacts; } // { ${checkConfig.argsAttr} = args; }
    );
in
{
  inherit craneLib mkCargoCheck;
}
