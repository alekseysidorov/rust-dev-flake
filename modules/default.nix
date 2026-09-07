{
  inputs,
  flake-parts-lib,
  ...
}:

let
  inherit (flake-parts-lib) importApply;

  # Bind provider-owned dependencies before exposing the module to consumers.
  packagesModule =
    importApply ./packages.nix {
      inherit (inputs)
        crane
        rust-overlay
        rust-advisory-db
        ;
    };

  # One aggregate module is both dogfooded locally and exported publicly.
  flakeModule = {
    imports = [
      packagesModule
      ./gitHooks.nix
      ./tests.nix
    ];
  };
in
{
  imports = [
    flakeModule
  ];

  config.flake.flakeModule = flakeModule;
}
