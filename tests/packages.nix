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
      };

      extendedPkgs = pkgs.extend inputs.self.overlays.default;
    in
    {
      checks = {
        test-packages-sibling-dependency = extendedPkgs.mkGitHooks {
          pre-commit = extendedPkgs.writeNushellScript "pre-commit" ''
            print "ok"
          '';
        };

        test-packages-rust-overlay = extendedPkgs.comchan;
      };
    };
}
