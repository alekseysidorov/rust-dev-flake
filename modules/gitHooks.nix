{ lib, flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, pkgs, ... }:
    {
      options.gitHooks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.package);
        default = { };
        description = "Git hook names mapped to executable script files.";
      };

      config = lib.mkIf (config.gitHooks != { }) {
        # Import locally: the consuming flake need not expose our library in flake.lib.
        packages.install-git-hooks = ((import ../lib/git-hooks.nix).mkLib pkgs.buildPackages).mkGitHooks config.gitHooks;
      };
    }
  );
}
