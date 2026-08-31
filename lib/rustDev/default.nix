{ inputs }:
{
  mkCraneLib = { pkgs, toolchain }: (inputs.crane.mkLib pkgs).overrideToolchain toolchain;
  mkRustDevHelpers = import ./mkRustDevHelpers.nix { inherit inputs; };
}
