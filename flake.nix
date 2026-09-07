{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crane.url = "github:ipetkov/crane";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      imports = [
        inputs.treefmt-nix.flakeModule
        ./modules
      ];

      perSystem =
        {
          localPkgs,
          ...
        }:
        {
          # Repository-specific formatting policy.
          treefmt = {
            projectRootFile = "flake.nix";

            programs = {
              nixfmt.enable = true;
              deno.enable = true;
            };
          };

          # Repository-specific hook policy uses internal package capabilities.
          gitHooks = {
            pre-commit = localPkgs.writeNushellScript "pre-commit" ''
              print "⚡️ Running pre-commit checks..."
              nix fmt -- --fail-on-change
            '';

            pre-push = localPkgs.writeNushellScript "pre-push" ''
              print "⚡️ Running pre-push checks..."
              nix flake check -L
            '';
          };
        };
    };
}
