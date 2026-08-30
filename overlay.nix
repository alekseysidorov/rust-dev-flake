{ inputs }:

final: prev:
let
  pkgs = final;
  rustDev = import ./lib/rustDev { inherit inputs; };
  gitHooks = import ./lib/git-hooks.nix;
in
{
  rustDev = {
    mkCraneLib = args: rustDev.mkCraneLib (args // { inherit pkgs; });
    mkRustDevHelpers = args: rustDev.mkRustDevHelpers (args // { inherit pkgs; });
  };
  gitHooks = gitHooks.mkLib final.buildPackages;
}
