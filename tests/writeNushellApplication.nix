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

      app = pkgs.writeNushellApplication {
        name = "write-nushell-application-test";

        runtimeEnv.TEST_VALUE = "works";

        text = ''
          if $env.TEST_VALUE != "works" {
            error make { msg: "runtimeEnv was not loaded" }
          }
        '';
      };
    in
    {
      checks.test-write-nushell-application =
        pkgs.runCommand "test-write-nushell-application"
          {
            nativeBuildInputs = [ app ];
          }
          ''
            write-nushell-application-test
            touch $out
          '';
    };
}
