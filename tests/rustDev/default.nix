{
  inputs,
  ...
}:

{
  perSystem =
    { system, ... }:

    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          inputs.self.overlays.default
        ];
      };

      rustDev = pkgs.mkRustDevHelpers {
        inherit pkgs;
        src = pkgs.projectSource {
          projectRoot = ./.;
          sourceDir = "fixtures";
        };
      };
    in
    {
      checks.test-rust-dev = rustDev.checks.nextest "--workspace";
    };
}
