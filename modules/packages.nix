{
  inputs,
  lib,
  flake-parts-lib,
  ...
}:

let
  # Build the local package-set extensions against an arbitrary nixpkgs instance.
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

  # Compose external package-set capabilities with this repository's own extensions.
  # Consumers get rust-overlay and all local builders/packages through one overlay.
  localOverlay = final: _prev: loadPackages final;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:

    let
      # Internal view of local package-set extensions for reusable flake modules.
      # Functions remain private here, while concrete derivations can be exported below.
      localPkgs = loadPackages pkgs;

      packages = lib.filterAttrs (_: value: lib.isDerivation value) localPkgs;
    in
    {
      config = {
        _module.args.localPkgs = localPkgs;

        # Publish only buildable values as flake packages and test all of them automatically.
        inherit packages;
        checks = packages;
      };
    }
  );

  config = {
    # Expose a single package-set API: rust-overlay first, then local package definitions.
    flake.overlays.default = lib.composeManyExtensions [
      inputs.rust-overlay.overlays.default
      localOverlay
    ];

    # Export this capability so consuming flakes can reuse the same package wiring.
    flake.modules.flake.packages = ./packages.nix;
  };
}
