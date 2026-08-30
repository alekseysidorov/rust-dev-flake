{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    crane.url = "github:ipetkov/crane";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-utils.url = "github:numtide/flake-utils";

    rust-advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    inputs:
    {
      lib = import ./lib { inherit inputs; };
      overlays.default = import ./overlay.nix { inherit inputs; };
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
      in
      {
        formatter = treefmt.config.build.wrapper;
        checks.formatter = treefmt.config.build.check inputs.self;

        packages.git-install-hooks = inputs.self.lib.gitHooks.mkGitHooks { inherit pkgs; } {
          "pre-commit" = ''
            echo "⚡️ Running pre-commit checks..."
            nix flake check -L
          '';
        };
      }
    );
}
