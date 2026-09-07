{ lib, flake-parts-lib, ... }:

{
  imports = [
    ./packages.nix
  ];

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      pkgsLocal,
      ...
    }:

    {
      options.gitHooks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.package);

        default = { };

        description = "Git hook names mapped to executable script files.";
      };

      config = lib.mkIf (config.gitHooks != { }) {
        packages.install-git-hooks = pkgsLocal.mkGitHooks config.gitHooks;
      };
    }
  );
}
