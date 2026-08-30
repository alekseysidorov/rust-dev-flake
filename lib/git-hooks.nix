{
  mkLib = pkgs: {
    # Hooks map Git hook names to executable files, not script bodies.
    mkGitHooks =
      hooks:
      let
        inherit (pkgs) lib;

        installHook = name: script: ''
          install -m755 ${script} "$hooksDir"/${lib.escapeShellArg name}
          echo ${lib.escapeShellArg "⚡️ Installed ${name} hook"}
        '';

        # Generate shell code; installation happens only when the installer is run.
        installHooks = lib.pipe hooks [
          (lib.mapAttrsToList installHook)
          (lib.concatStringsSep "\n")
        ];
      in
      pkgs.writeShellApplication {
        name = "install-git-hooks";
        runtimeInputs = [
          pkgs.git
          pkgs.coreutils
        ];
        text = ''
          hooksDir=$(git rev-parse --git-path hooks)
          mkdir -p "$hooksDir"

          ${installHooks}
        '';
      };
  };
}
