# Nix flake for context-logger development and CI
#
# All reusable infrastructure lives in ./dev-flake.
# This file only contains project-specific configuration.
#
# Usage:
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
#   nix run .#check-semver       - Run semver compatibility checks (requires network)
#   nix run .#git-install-hooks  - Install git hooks (pre-commit: fmt, pre-push: checks + semver)
#
#   nix develop                  - Enter development shell with stable Rust
#   nix develop .#nightly        - Enter development shell with nightly Rust
{
  inputs.dev-flake.url = "path:./dev-flake";

  outputs =
    { self, dev-flake }:
    dev-flake.lib.mkRustProject {
      inherit self;

      msrv = {
        name = "1.85.1";
        sha256 = "sha256-Hn2uaQzRLidAWpfmRwSRdImifGUCAb9HeAqTYFXWeQk=";
      };

      devShellInputs = pkgs: [
        pkgs.cargo-machete
      ];
    };
}
