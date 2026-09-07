{
  inputs,
  ...
}:

{
  perSystem =
    {
      localPkgs,
      system,
      ...
    }:

    let
      # Deliberately use plain nixpkgs: package capabilities must not depend
      # on the repository installing its public overlay into perSystem.pkgs.
      pkgs = import inputs.nixpkgs {
        inherit system;
      };
    in
    {
      _module.args.pkgs = pkgs;

      checks = {
        # Sibling package-set dependencies must resolve through the local fixed point.
        test-packages-sibling-dependency = localPkgs.mkGitHooks {
          pre-commit = localPkgs.writeNushellScript "pre-commit" ''
            print "ok"
          '';
        };

        # rust-overlay must be part of the local package universe as well.
        test-packages-rust-overlay = localPkgs.comchan;
      };
    };
}
