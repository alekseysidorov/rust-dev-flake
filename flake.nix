{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crane.url = "github:ipetkov/crane";

    treefmt-nix.url = "github:numtide/treefmt-nix";

    rust-advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      imports = [
        ./modules
        inputs.treefmt-nix.flakeModule
      ];

      flake.lib = import ./lib { inherit inputs; };

      perSystem =
        {
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;

            overlays = [
              inputs.self.overlays.default
            ];
          };

          treefmt = {
            projectRootFile = "flake.nix";

            programs = {
              nixfmt.enable = true;
              deno.enable = true;
            };
          };

          gitHooks = {
            pre-commit = pkgs.writeNushellScript "pre-commit" ''
              print "⚡️ Running pre-commit checks..."
              nix fmt -- --fail-on-change
            '';

            pre-push = pkgs.writeNushellScript "pre-push" ''
              print "⚡️ Running pre-push checks..."
              nix flake check -L
            '';
          };
        };
    };
}
