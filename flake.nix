{
  inputs = {
    # Nix
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Build
    crane.url = "github:ipetkov/crane";

    # Development
    treefmt-nix.url = "github:numtide/treefmt-nix";
    rust-advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ./flake-modules/git-hooks.nix ];
      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      flake = {
        lib = import ./lib { inherit inputs; };
        overlays.default = import ./overlay.nix { inherit inputs; };
        flakeModules.gitHooks = ./flake-modules/git-hooks.nix;
      };

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
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
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
          };

          formatter = treefmt.config.build.wrapper;
          checks = {
            formatter = treefmt.config.build.check inputs.self;
            diplomat-tool = config.packages.diplomat-tool;
          };
          packages = {
            inherit (pkgs) diplomat-tool;
          };

          gitHooks = {
            pre-commit = pkgs.writeShellScript "pre-commit" ''
              set -euo pipefail
              echo "⚡️ Running pre-commit checks..."
              nix build .#checks.${system}.formatter -L
            '';

            pre-push = pkgs.writeShellScript "pre-push" ''
              set -euo pipefail
              echo "⚡️ Running pre-push checks..."
              nix flake check -L
            '';
          };
        };
    };
}
