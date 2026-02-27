{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs:
    {
      lib.mkRustDevHelpers = import ./lib/default.nix { inherit inputs; };
    }
    // inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        # Eval the treefmt configuration
        treefmt = (inputs.treefmt-nix.lib.evalModule pkgs) {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
            deno.enable = true;
          };
        };
        # Use rust dev helpers for git hooks
        rustDev = inputs.self.lib.mkRustDevHelpers {
          inherit system;
          self = inputs.self;
          toolchain = pkgs.rustc;
        };
      in
      {
        formatter = treefmt.config.build.wrapper;
        checks.formatter = treefmt.config.build.wrapper;
        packages.git-install-hooks = rustDev.mkGitHooks {
          "pre-commit" = ''
            echo "⚡️ Running pre-commit checks..."
            nix flake check -L
          '';
        };
      }
    );
}
