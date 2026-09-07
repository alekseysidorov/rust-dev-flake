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
          projectRoot = ./../..;
          sourceDir = "tests/rustDev/fixtures";
        };
      };
    in
    {
      checks.test-rust-dev-nextest = rustDev.checks.nextest "--workspace";
      checks.test-rust-dev-audit = rustDev.checks.audit "";
    };
}
