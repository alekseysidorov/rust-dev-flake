localInputs:

{
  ...
}:

{
  imports = [
    ./packages.nix
    ./gitHooks.nix
    ./tests.nix
  ];

  _module.args.localInputs = localInputs;
}
