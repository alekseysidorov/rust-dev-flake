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
  # Runtime dependencies for the project
  runtimeInputs ? [ ],
}:

let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  pkgs-unstable = inputs.nixpkgs.legacyPackages.${system};
  # Crane uses MSRV toolchain to verify minimum version compatibility
  craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;
  # Use project source as-is without filtering
  src = root;
  # Common arguments for all crane builds
  commonArgs = {
    inherit src buildInputs nativeBuildInputs;
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

  # Helper: generate git hooks installer script
  mkGitHooks =
    hooks:
    pkgs.writeShellApplication {
      name = "install-git-hooks";
      text = pkgs.lib.concatMapStrings (hookName: ''
        echo "⚡️ Installing ${hookName} hook"
        cat > "$PWD/.git/hooks/${hookName}" << 'EOF'
        ${pkgs.runtimeShell}
        set -euo pipefail
        ${hooks.${hookName}}
        EOF
        chmod +x "$PWD/.git/hooks/${hookName}"
      '') (pkgs.lib.attrNames hooks);
    };

  runtimeChecks = import ./runtimeChecks.nix {
    inherit pkgs pkgs-unstable runtimeInputs;
  };
in
{
  inherit
    craneLib
    mkCargoCheck
    mkGitHooks
    runtimeChecks
    ;
}
