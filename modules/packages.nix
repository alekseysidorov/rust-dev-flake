{
  inputs,
  lib,
  flake-parts-lib,
  ...
}:

let
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
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      config._module.args.localPkgs = loadPackages pkgs;
    }
  );

  config.flake = {
    overlays.default = final: _prev: loadPackages final;
    modules.flake.packages = ./packages.nix;
  };
}
