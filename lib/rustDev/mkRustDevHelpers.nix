# Rust project helpers
#
# Returns: { toolchain, craneLib, mkCargoCheck, mkCheckPackages, runtimeChecks }

{ inputs }:
{
  # The calling flake's source, used as the default projectRoot.
  self,
  # Legacy callers may pass system; pkgs preserves overlays and cross configuration.
  system ? pkgs.stdenv.buildPlatform.system,
  pkgs ? inputs.nixpkgs.legacyPackages.${system},
  # Rust toolchain derivation, or pkgs -> derivation for Crane's cross splicing.
  # Not bundled intentionally — bring your own via
  # fenix, rust-overlay, or plain nixpkgs. Typically set to your MSRV toolchain
  # so that crane validates minimum-version compatibility on every build.
  toolchain,
  # Path to the project root passed to crane as the source tree.
  # Defaults to the calling flake's source.
  projectRoot ? self,
  # Build-time C/C++ libraries passed to every crane derivation via buildInputs
  buildInputs ? [ ],
  # Native build-time tools passed to every crane derivation via nativeBuildInputs
  nativeBuildInputs ? [ ],
  # Packages injected into the PATH of every runtimeChecks shell script.
  # Should include your Rust toolchain and any C libraries the binary links against
  runtimeInputs ? [ ],
}:

let
  advisory-db = inputs.rust-advisory-db;

  # Crane instance with the caller-provided toolchain already wired in.
  # All mkCargoCheck derivations are built with this toolchain.
  craneLib = inputs.self.lib.mkCraneLib { inherit pkgs toolchain; };

  src = projectRoot;

  # Shared arguments forwarded to every crane derivation.
  # cargoVendorDir is computed once so the network fetch is not repeated.
  commonArgs = {
    inherit src buildInputs nativeBuildInputs;
    strictDeps = true;
    cargoVendorDir = craneLib.vendorCargoDeps { inherit src; };
  };

  # Dependencies-only build result, shared as `cargoArtifacts` across all
  # checks so that the dependency compilation step is cached and not repeated
  # for each individual check.
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  # mkCargoCheck checkType extraArgs
  #
  # Creates a sandboxed crane derivation suitable for `nix flake check`.
  # The derivation is built inside the Nix sandbox — no network access.
  #
  # checkType — one of:
  #   "nextest"  →  cargo nextest run  (requires cargo-nextest in nativeBuildInputs
  #                 or added by crane automatically via cargoNextest)
  #   "clippy"   →  cargo clippy
  #   "test"     →  cargo test         (use for --doc tests; nextest doesn't run them)
  #   "doc"      →  cargo doc
  #
  # extraArgs — flags appended to the cargo command.
  mkCargoCheck =
    checkType: args:
    let
      dispatchTable = {
        nextest = {
          builder = craneLib.cargoNextest;
          argsAttr = "cargoNextestExtraArgs";
          extraArgs = { };
        };
        clippy = {
          builder = craneLib.cargoClippy;
          argsAttr = "cargoClippyExtraArgs";
          extraArgs = { };
        };
        test = {
          builder = craneLib.cargoTest;
          argsAttr = "cargoTestExtraArgs";
          extraArgs = { };
        };
        doc = {
          builder = craneLib.cargoDoc;
          argsAttr = "cargoDocExtraArgs";
          extraArgs = { };
        };
        audit = {
          builder = craneLib.cargoAudit;
          argsAttr = "cargoAuditExtraArgs";
          extraArgs = {
            inherit advisory-db;
          };
        };
      };
      cfg = dispatchTable.${checkType};
    in
    cfg.builder (
      commonArgs // { inherit cargoArtifacts; } // { ${cfg.argsAttr} = args; } // cfg.extraArgs
    );

  # mkCheckPackages checks
  #
  # Converts a checks attribute set into a packages attribute set with each
  # name prefixed by "check-", so that individual checks can be triggered
  # outside of `nix flake check` via `nix build .#check-<name>`.
  mkCheckPackages =
    checks:
    pkgs.lib.mapAttrs' (name: value: {
      name = "check-" + name;
      inherit value;
    }) checks;

  runtimeChecks = import ./runtimeChecks.nix {
    inherit pkgs runtimeInputs;
  };
in
{
  inherit craneLib;
  # Crane accepts a package or a function selecting one per platform. Expose a
  # concrete package for dev shells: the compiler must run on the build machine,
  # even when its output targets another platform.
  toolchain = if builtins.isFunction toolchain then toolchain pkgs.buildPackages else toolchain;

  inherit
    mkCargoCheck
    mkCheckPackages
    runtimeChecks
    ;
}
