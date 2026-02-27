# rust-dev-flake — library entry point
#
# Usage:
#   rustDev = rust-dev-flake.lib.rustDevFlake {
#     inherit system self;
#     toolchain     = fenixPkgs.stable.completeToolchain;
#     runtimeInputs = [ toolchain ];
#   };
#
# Returns: { craneLib, mkCargoCheck, mkCheckPackages, mkGitHooks, runtimeChecks }

{ inputs }:
{
  # The calling flake's `self` (passed to treefmt.check and used as default root)
  self,
  # Target system string, e.g. "x86_64-linux" or "aarch64-darwin"
  system,
  # Rust toolchain derivation. Not bundled intentionally — bring your own via
  # fenix, rust-overlay, or plain nixpkgs. Typically set to your MSRV toolchain
  # so that crane validates minimum-version compatibility on every build.
  toolchain,
  # Path to the project root passed to crane as the source tree.
  # Defaults to `self`. Override with `root = ./.;` if you need a plain path
  # instead of a flake source (e.g. to avoid IFD issues).
  root ? self,
  # Build-time C/C++ libraries passed to every crane derivation via buildInputs
  # (e.g. [ pkgs.openssl pkgs.sqlite ]).
  buildInputs ? [ ],
  # Native build-time tools passed to every crane derivation via nativeBuildInputs
  # (e.g. [ pkgs.pkg-config pkgs.cmake ]).
  nativeBuildInputs ? [ ],
  # Packages injected into the PATH of every runtimeChecks shell script.
  # Should include your Rust toolchain and any C libraries the binary links against
  # (e.g. [ rustToolchains.stable pkgs.openssl ]).
  runtimeInputs ? [ ],
}:

let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};

  # Crane instance with the caller-provided toolchain already wired in.
  # All mkCargoCheck derivations are built with this toolchain.
  craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;

  src = root;

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
  # extraArgs — string of flags appended to the cargo command, e.g.:
  #   "--workspace --all-targets --all-features -- --deny warnings"
  #
  # Example:
  #   checks.clippy = rustDev.mkCargoCheck "clippy"
  #     "--workspace --all-targets --all-features -- --deny warnings";
  mkCargoCheck =
    checkType: args:
    let
      dispatchTable = {
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
      cfg = dispatchTable.${checkType};
    in
    cfg.builder (commonArgs // { inherit cargoArtifacts; } // { ${cfg.argsAttr} = args; });

  # mkCheckPackages checks
  #
  # Converts a checks attribute set into a packages attribute set with each
  # name prefixed by "check-", so that individual checks can be triggered
  # outside of `nix flake check` via `nix build .#check-<name>`.
  #
  # Example:
  #   packages = rustDev.mkCheckPackages self.checks.${system};
  #   # enables: nix build .#check-clippy
  #   #          nix build .#check-tests
  mkCheckPackages =
    checks:
    pkgs.lib.mapAttrs' (name: value: {
      name = "check-" + name;
      inherit value;
    }) checks;

  # mkGitHooks { "<hook-name>" = shellScript; … }
  #
  # Generates a `writeShellApplication` derivation that, when run with
  # `nix run .#<name>`, writes the provided shell snippets into .git/hooks/.
  # Each hook file is made executable and gets a strict shebang + set -euo pipefail.
  #
  # Hook names are standard git hook names: "pre-commit", "pre-push", etc.
  # The hook body is a plain shell string (no shebang needed).
  #
  # Example:
  #   packages.git-install-hooks = rustDev.mkGitHooks {
  #     pre-commit = "nix build .#check-formatting -L";
  #     pre-push   = ''
  #       nix flake check -L
  #       nix run .#check-cargo-semver -L
  #     '';
  #   };
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
  # Pre-configured crane instance. Use directly for anything not covered by
  # mkCargoCheck, e.g.: packages.default = rustDev.craneLib.buildPackage { inherit src; };
  inherit craneLib;

  inherit
    mkCargoCheck
    mkCheckPackages
    mkGitHooks
    runtimeChecks
    ;
}
