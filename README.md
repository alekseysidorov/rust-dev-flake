# rust-dev-flake

[![Nix Flake](https://img.shields.io/badge/Nix-Flake-blue.svg)](https://nixos.org/nix/flakes)
[![Rust](https://img.shields.io/badge/Rust-stable-orange.svg)](https://www.rust-lang.org)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A collection of Nix helpers to simplify Rust project maintenance and ensure
reproducible tooling — both locally and in CI.

## Example

```nix
# Nix flake for my-crate development and CI
#
# nix flake check              — run all checks (formatting, clippy, tests, docs)
# nix fmt                      — format all files
#
# nix build .#check-clippy     — run only clippy
# nix build .#check-tests      — run only tests (no default features)
# nix build .#check-tests-all  — run tests with all features
# nix build .#check-doc        — check documentation builds
# nix build .#check-doc-tests  — run doc tests
# nix build .#check-formatting — check formatting
#
# nix run .#benchmarks         — run benchmarks
# nix run .#check-cargo-semver — semver compatibility check (requires network)
# nix run .#git-install-hooks  — install git hooks
#
# nix develop                  — dev shell with stable Rust
{
  inputs = {
    nixpkgs.url        = "github:NixOS/nixpkgs/nixos-25.11";
    fenix.url          = "github:nix-community/fenix/monthly";
    treefmt-nix.url    = "github:numtide/treefmt-nix";
    flake-utils.url    = "github:numtide/flake-utils";
    rust-dev-flake.url = "github:wildboarder/rust-dev-flake";
  };

  outputs = { self, nixpkgs, flake-utils, fenix, treefmt-nix, rust-dev-flake }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs      = nixpkgs.legacyPackages.${system};
        fenixPkgs = fenix.packages.${system};

        rustToolchains = {
          stable  = fenixPkgs.stable.completeToolchain;
          nightly = fenixPkgs.complete.withComponents [ "rustfmt" ];
        };

        rustDev = rust-dev-flake.lib.mkRustDevHelpers {
          inherit system self;
          toolchain     = rustToolchains.stable;
          runtimeInputs = [ rustToolchains.stable ];
        };

        # treefmt-nix lets you mix formatters freely — including overriding
        # the rustfmt package to nightly so you can use unstable format options.
        treefmt = (treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
            rustfmt        = { enable = true; package = rustToolchains.nightly; }; # nightly rustfmt!
            taplo.enable   = true;
          };
        }).config.build;

        checks = {
          formatting = treefmt.check self;
          tests      = rustDev.mkCargoCheck "nextest" "--workspace --all-targets --no-default-features";
          tests-all  = rustDev.mkCargoCheck "nextest" "--workspace --all-targets --all-features";
          clippy     = rustDev.mkCargoCheck "clippy"  "--workspace --all-targets --all-features -- --deny warnings";
          doc-tests  = rustDev.mkCargoCheck "test"    "--workspace --doc --all-features";
          docs       = rustDev.mkCargoCheck "doc"     "--workspace --no-deps --all-features";
        };
      in
      {
        formatter = treefmt.wrapper;
        inherit checks;

        packages = (rustDev.mkCheckPackages checks) // {
          inherit (rustDev.runtimeChecks)
            check-cargo-semver
            check-cargo-publish
            benchmarks;

          git-install-hooks = rustDev.mkGitHooks {
            pre-commit = "nix build .#check-formatting -L";
            pre-push   = ''
              nix flake check -L
              nix run .#check-cargo-semver -L
              nix run .#check-cargo-publish -L
            '';
          };
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [ rustToolchains.stable treefmt.wrapper ];
        };
      }
    );
}
```

## License

MIT — see [LICENSE](LICENSE).
