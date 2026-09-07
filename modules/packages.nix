{
  inputs,
  lib,
  flake-parts-lib,
  ...
}:

let
  # Build this repository's package-set extensions against an arbitrary nixpkgs instance.
  # Flake inputs are injected explicitly so package definitions do not depend on `inputs`.
  loadPackages =
    pkgs:
    lib.filesystem.packagesFromDirectoryRecursive {
      directory = ../pkgs;

      callPackage = lib.callPackageWith (
        pkgs
        // {
          inherit (inputs)
            crane
            rust-advisory-db
            ;
        }
      );
    };

  # Local packages are evaluated against `final`, so package definitions can depend
  # on sibling builders and on capabilities introduced by preceding overlays.
  localOverlay = final: _prev: loadPackages final;

  # Keep the internal package universe and the public overlay on exactly the same wiring.
  packageOverlay = lib.composeManyExtensions [
    inputs.rust-overlay.overlays.default
    localOverlay
  ];
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:

    let
      # Extend the caller's package set locally instead of requiring the consumer
      # to install our public overlay before importing this module.
      extendedPkgs = pkgs.extend packageOverlay;

      localPkgs = loadPackages extendedPkgs;
    in
    {
      config = rec {
        _module.args.localPkgs = localPkgs;

        # Publish only concrete buildable values; package-set functions stay in the overlay.
        packages = lib.filterAttrs (_: value: lib.isDerivation value) localPkgs;
        checks = packages;
      };
    }
  );

  config = {
    # Consumers get rust-overlay and all local builders/packages through one overlay.
    flake.overlays.default = lib.mkDefault packageOverlay;

    # Export the package wiring as a self-contained reusable flake module.
    flake.modules.flake.packages = ./packages.nix;
  };
}
