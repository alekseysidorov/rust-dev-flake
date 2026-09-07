{
  imports = [
    ./gitHooks.nix
    ./packages.nix
    ./tests.nix
  ];

  config.flake.flakeModule = ./default.nix;
}
