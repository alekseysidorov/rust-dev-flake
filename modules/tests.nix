{ lib, ... }:

{
  imports = builtins.filter (path: lib.hasSuffix ".nix" (toString path)) (
    lib.filesystem.listFilesRecursive ../tests
  );

  config.flake.modules.flake.tests = ./tests.nix;
}
