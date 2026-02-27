{
  # Flake inputs
  inputs,
  # The calling flake's `self`
  self,
  # Target system architecture
  system,
  # Path to the project root (used for crane source filtering)
  # Defaults to `self`; pass `./.` explicitly if needed
  root ? self,
  # Minimum supported Rust version
  # Example: { name = "1.85.1"; sha256 = "sha256-..."; }
  msrv,
  buildInputs ? [ ],
  nativeBuildInputs ? [ ],
}:

let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  # Crane uses MSRV toolchain to verify minimum version compatibility
  craneLib = (inputs.crane.mkLib pkgs).overrideToolchain msrv;
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
