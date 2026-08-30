{
  mkGitHooks =
    { pkgs }:
    hooks:
    let
      inherit (pkgs) lib;

      makeHook =
        name: body:
        pkgs.writeShellScript name ''
          set -euo pipefail
          ${body}
        '';

      installHook = name: script: ''
        install -m755 ${script} "$hooksDir"/${lib.escapeShellArg name}
        echo ${lib.escapeShellArg "Installed ${name} hook"}
      '';

      # Turn hook bodies into store scripts, then join their installation commands.
      # This generates shell code; installation happens when the installer is run.
      installHooks = lib.pipe hooks [
        (lib.mapAttrs makeHook)
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
}
