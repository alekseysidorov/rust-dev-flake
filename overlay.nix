{ inputs }:

final: prev:
let
  pkgs = final;
  rustDev = import ./lib { inherit inputs; };
  gitHooks = import ./git-hooks.nix;
in
{
  rustDev = {
    mkCraneLib = args: rustDev.mkCraneLib (args // { inherit pkgs; });
    mkRustDevHelpers = args: rustDev.mkRustDevHelpers (args // { inherit pkgs; });
  };
  gitHooks = gitHooks.mkLib final.buildPackages;
}
