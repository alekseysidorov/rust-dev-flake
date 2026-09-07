{
  lib,
  flake-parts-lib,
  localInputs,
  ...
}:

let
  # Build local package-set extensions against an arbitrary nixpkgs instance.
  # Provider-owned inputs are injected explicitly into package definitions.
  loadPackages =
    pkgs:
    lib.filesystem.packagesFromDirectoryRecursive {
      directory = ../pkgs;

      callPackage = lib.callPackageWith (
        pkgs
        // {
          inherit (localInputs)
            crane
            rust-advisory-db
            ;
        }
      );
    };

  # Evaluate local packages against the final package-set fixed point.
  # This lets package definitions depend on sibling builders and preceding overlays.
  localOverlay = final: _prev: loadPackages final;

  # Keep one canonical package universe for internal use and external consumers.
  packageOverlay = lib.composeManyExtensions [
    localInputs.rust-overlay.overlays.default
    localOverlay
  ];
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:

    let
      # Extend the caller's package set locally so the module is self-contained.
      extendedPkgs = pkgs.extend packageOverlay;

      # Internal package-set capabilities for other modules and repository policy.
      pkgsLocal = loadPackages extendedPkgs;
    in
    {
      config = {
        _module.args.pkgsLocal = lib.mkDefault pkgsLocal;
      };
    }
  );

  # Provide a convenient fallback without overriding the consumer's own composition.
  config.flake.overlays.default = lib.mkDefault packageOverlay;
}
