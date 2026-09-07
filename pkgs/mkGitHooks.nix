{
  lib,
  buildPackages,
  writeNushellApplication,
}:

hooks:

let
  installHook = name: script: ''
    cp ${script} ($hooksDir | path join ${builtins.toJSON name})
    chmod +x ($hooksDir | path join ${builtins.toJSON name})
    print ${builtins.toJSON "⚡️ Installed ${name} hook"}
  '';

  installHooks = lib.pipe hooks [
    (lib.mapAttrsToList installHook)
    (lib.concatStringsSep "\n")
  ];
in
writeNushellApplication {
  name = "install-git-hooks";

  runtimeInputs = [
    buildPackages.git
    buildPackages.coreutils
  ];

  text = ''
    let hooksDir = (git rev-parse --git-path hooks)
    mkdir $hooksDir

    ${installHooks}
  '';
}
