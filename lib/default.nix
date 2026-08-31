{ inputs }:
let
  rustDev = import ./rustDev { inherit inputs; };
in
{
  gitHooks = import ./git-hooks.nix;
  inherit (rustDev) mkCraneLib mkRustDevHelpers;
}
