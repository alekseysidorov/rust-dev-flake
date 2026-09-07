{
  imports = [
    ./gitHooks.nix
    ./packages.nix
  ];

  flake.modules.flake = {
    gitHooks = ./gitHooks.nix;
    packages = ./packages.nix;
  };
}
