# Reusable Nix flake for Rust project development and CI
#
# Provides `lib.mkRustProject` that generates a complete flake output
# with checks, dev shells, formatting, and convenience packages.
#
# Usage from a project flake:
#
#   {
#     inputs.dev-flake.url = "path:./dev-flake";
#
#     outputs = { self, dev-flake }:
#       dev-flake.lib.mkRustProject {
#         inherit self;
#         msrv = {
#           name = "1.85.1";
#           sha256 = "sha256-...";
#         };
#       };
#   }
#
# Available outputs:
#   nix flake check              - Run all checks (formatting, clippy, tests, docs)
#   nix fmt                      - Format code
#
#   nix build .#check-clippy     - Run only clippy
#   nix build .#check-tests      - Run only tests (no default features)
#   nix build .#check-tests-all  - Run tests with all features
#   nix build .#check-doc        - Check documentation builds
#   nix build .#check-doc-tests  - Run doc tests
#   nix build .#check-fmt        - Check formatting
#
#   nix run .#benchmarks         - Run benchmarks
#   nix run .#runtime-checks     - Run all runtime checks (semver, publish, etc.)
#   nix run .#check-semver       - Run semver compatibility checks (requires network)
#   nix run .#check-cargo-publish - Run cargo publish dry-run (requires network)
#   nix run .#git-install-hooks  - Install git hooks (pre-commit: fmt, pre-push: checks + runtime)
#
#   nix develop                  - Enter development shell with stable Rust
#   nix develop .#nightly        - Enter development shell with nightly Rust
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix.url = "github:nix-community/fenix/monthly";
    crane.url = "github:ipetkov/crane";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs: {
    lib.mkRustProject =
      {
        # The calling flake's `self` reference (used for treefmt source check)
        self,

        # Path to the project root (used for crane source filtering)
        # Defaults to `self`; pass `./.` explicitly if needed
        root ? self,

        # Minimum supported Rust version
        # Example: { name = "1.85.1"; sha256 = "sha256-..."; }
        msrv,

        # Treefmt programs configuration.
        # Each key is a formatter name, each value is its treefmt-nix config.
        # If rustfmt is enabled, the nightly toolchain package is injected automatically.
        # Type: { <program> = { enable = bool; ... }; ... }
        treefmt ? {
          nixfmt.enable = true;
          rustfmt.enable = true;
          beautysh.enable = true;
          deno.enable = true;
          taplo.enable = true;
        },

        # Native build dependencies required for compilation (e.g., openssl, pkg-config)
        # Type: pkgs -> [ derivation ]
        buildInputs ? _: [ ],

        # Extra packages available via `nix run .#<name>`
        # Type: pkgs -> { name = derivation; ... }
        extraPackages ? _: { },

        # Extra runtime checks (network-dependent, run via `nix run`).
        # These are merged with the built-in runtime checks (semver, cargo-publish)
        # and included in `nix run .#runtime-checks`.
        # Type: pkgs -> { name = derivation; ... }
        extraRuntimeChecks ? _: { },

        # Extra tools to include in the default dev shell
        # Type: pkgs -> [ derivation ]
        devShellInputs ? _: [ ],
      }:
      inputs.flake-utils.lib.eachDefaultSystem (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
          pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
          fenixPackage = inputs.fenix.packages.${system};

          rustToolchains = {
            stable = fenixPackage.stable.completeToolchain;
            msrv = (fenixPackage.fromToolchainName msrv).defaultToolchain;
            nightly = fenixPackage.complete.withComponents [ "rustfmt" ];
          };

          # Crane uses MSRV toolchain to verify minimum version compatibility
          craneLib = (inputs.crane.mkLib pkgs).overrideToolchain rustToolchains.msrv;

          # Treefmt configuration: inject nightly rustfmt package when rustfmt is enabled
          treefmtPrograms = builtins.mapAttrs (
            name: value: if name == "rustfmt" then value // { package = rustToolchains.nightly; } else value
          ) treefmt;

          treefmtEval =
            (inputs.treefmt-nix.lib.evalModule pkgs {
              projectRootFile = "flake.nix";
              programs = treefmtPrograms;
            }).config.build;

          # Merge user-provided build inputs with standard ones
          projectBuildInputs = [
            pkgs.cargo-nextest
          ]
          ++ (buildInputs pkgs);

          # Use project source as-is without filtering
          src = root;

          # Common arguments for all crane builds
          commonArgs = {
            inherit src;
            strictDeps = true;
            nativeBuildInputs = projectBuildInputs;
            cargoVendorDir = craneLib.vendorCargoDeps { inherit src; };
          };

          # Build dependencies only (for caching between checks)
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;

          # Helper: create a crane check derivation
          # Usage: mkCheck "nextest" "--workspace --all-targets --all-features"
          mkCheck =
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

          # Helper: prefix check names with "check-" for packages output
          mkCheckPackages =
            checks:
            pkgs.lib.mapAttrs' (name: value: {
              name = "check-" + name;
              inherit value;
            }) checks;

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

          # Standard CI checks (pure, sandboxed)
          checks = {
            formatting = treefmtEval.check self;

            tests = mkCheck "nextest" "--workspace --all-targets --no-default-features";
            tests-all-features = mkCheck "nextest" "--workspace --all-targets --all-features";
            clippy = mkCheck "clippy" "--workspace --all --all-targets --all-features -- --deny warnings";
            doc-tests = mkCheck "test" "--workspace --doc --all-features";
            doc = mkCheck "doc" "--workspace --no-deps --all-features";
          };

          # Runtime checks: require network access, run via `nix run`
          defaultRuntimeChecks = {
            check-semver = pkgs.writeShellApplication {
              name = "run-semver-checks";
              runtimeInputs = [
                rustToolchains.stable
                pkgs-unstable.cargo-semver-checks
              ]
              ++ projectBuildInputs;
              text = "cargo semver-checks";
            };

            check-cargo-publish = pkgs.writeShellApplication {
              name = "run-cargo-publish-checks";
              runtimeInputs = [
                rustToolchains.stable
              ]
              ++ projectBuildInputs;
              text = ''
                cargo publish --workspace --all-features --dry-run
              '';
            };
          };

          allRuntimeChecks = defaultRuntimeChecks // (extraRuntimeChecks pkgs);

          # Combined runner for all runtime checks
          runtimeChecksRunner = pkgs.writeShellApplication {
            name = "runtime-checks";
            text = pkgs.lib.concatStringsSep "\n" (
              pkgs.lib.mapAttrsToList (name: pkg: ''
                echo "⚡️ Running ${name}..."
                ${pkgs.lib.getExe pkg}
              '') allRuntimeChecks
            );
          };

          # Standard packages
          standardPackages = {
            # Benchmarks
            benchmarks = pkgs.writeShellApplication {
              name = "run-benchmarks";
              runtimeInputs = [ rustToolchains.stable ] ++ projectBuildInputs;
              text = ''
                cargo bench --workspace --all-features
              '';
            };

            # Convenience script to install git hooks
            git-install-hooks = mkGitHooks {
              "pre-commit" = ''
                echo "⚡️ Running pre-commit checks..."
                nix build .#check-formatting -L
              '';

              "pre-push" = ''
                echo "⚡️ Running flake checks..."
                nix flake check -L
                echo "⚡️ Running runtime checks..."
                nix run .#runtime-checks -L
              '';
            };

            # Combined runtime checks runner
            runtime-checks = runtimeChecksRunner;
          };
        in
        {
          # `nix fmt`
          formatter = treefmtEval.wrapper;

          # `nix flake check`
          inherit checks;

          devShells = {
            default = pkgs.mkShell {
              nativeBuildInputs =
                projectBuildInputs
                ++ [
                  rustToolchains.stable
                  treefmtEval.wrapper
                ]
                ++ (devShellInputs pkgs);
            };

            # Nightly shell for miri, etc.
            nightly = pkgs.mkShell {
              nativeBuildInputs = projectBuildInputs ++ [ rustToolchains.nightly ] ++ (devShellInputs pkgs);
            };
          };

          packages = standardPackages // allRuntimeChecks // mkCheckPackages checks // (extraPackages pkgs);
        }
      );
  };
}
