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
      lib.rustDevFlake = import ./lib/default.nix { inherit inputs; };
    }
    // inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        # Eval the treefmt configuration
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        treefmtConfig = {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
            deno.enable = true;
          };
        };
        treefmt = (inputs.treefmt-nix.lib.evalModule pkgs treefmtConfig).config.build;
      in
      {
        formatter = treefmt.wrapper;
        checks = {
          formatter = treefmt.wrapper;
        };
      }
    );
}
