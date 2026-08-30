{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    crane.url = "github:ipetkov/crane";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-parts.url = "github:hercules-ci/flake-parts";

    rust-advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      flake = {
        lib = import ./lib { inherit inputs; };
        overlays.default = import ./overlay.nix { inherit inputs; };
      };

      perSystem =
        { pkgs, system, ... }:
        let
          gitHooks = inputs.self.lib.gitHooks.mkLib pkgs;
          # Eval the treefmt configuration
          treefmt = (inputs.treefmt-nix.lib.evalModule pkgs) {
            projectRootFile = "flake.nix";
            programs = {
              nixfmt.enable = true;
              deno.enable = true;
            };
          };
        in
        {
          formatter = treefmt.config.build.wrapper;
          checks.formatter = treefmt.config.build.check inputs.self;

          packages.git-install-hooks = gitHooks.mkGitHooks {
            pre-commit = pkgs.writeShellScript "pre-push" ''
              set -euo pipefail
              echo "⚡️ Running pre-push checks..."
              nix build .#checks.${system}.formatter -L
            '';

            pre-push = pkgs.writeShellScript "pre-commit" ''
              set -euo pipefail
              echo "⚡️ Running pre-commit checks..."
              nix flake check -L
            '';
          };
        };
    };
}
