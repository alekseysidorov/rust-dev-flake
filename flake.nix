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
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      {
        flake-parts-lib,
        ...
      }:

      let
        inherit (flake-parts-lib) importApply;

        # Capture nix-devtools' own inputs once, then reuse the exact same
        # module both internally and as the public flakeModule.
        flakeModule = importApply ./modules {
          inherit (inputs)
            crane
            rust-overlay
            rust-advisory-db
            ;
        };
      in
      {
        systems = inputs.nixpkgs.lib.systems.flakeExposed;

        imports = [
          inputs.treefmt-nix.flakeModule
          flakeModule
        ];

        flake.flakeModule = flakeModule;

        perSystem =
          {
            localPkgs,
            lib,
            ...
          }:
          rec {
            treefmt = {
              projectRootFile = "flake.nix";

              programs = {
                nixfmt.enable = true;
                deno.enable = true;
              };
            };

            # Only concrete derivations belong in flake packages and automatic checks.
            packages = lib.filterAttrs (_: value: lib.isDerivation value) localPkgs;
            checks = packages;

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
      }
    );
}
