{
  lib,
  nushell,
  writeText,
  writeTextFile,
}:

/*
  Like writeShellApplication, but text is Nu code and runs without a Bash wrapper.
  runtimeInputs prepend PATH; inheritPath keeps the caller's PATH by default.
  runtimeEnv contains environment values, not secrets: they enter the Nix store.
  Syntax is checked without executing the script; checkPhase can override this.
*/
{
  name,
  text,
  runtimeInputs ? [ ],
  runtimeEnv ? null,
  inheritPath ? true,
  meta ? { },
  passthru ? { },
  checkPhase ? null,
  derivationArgs ? { },
}:
let
  nu = lib.getExe nushell;
  runtimePath = builtins.toJSON (map (pkg: "${lib.getBin pkg}/bin") runtimeInputs);
  inheritedPath = lib.optionalString inheritPath " ++ ($env.PATH? | default [])";

  # Keep environment values as data, not executable Nu code.
  environment = writeText "${name}-env.json" (
    builtins.toJSON (lib.mapAttrs (_: value: toString value) runtimeEnv)
  );
  loadEnvironment = lib.optionalString (runtimeEnv != null) "load-env (open ${environment})";

  syntaxCheck = ''
    target="$target" ${nu} --no-config-file -c 'nu-check --debug $env.target | if not $in { exit 1 }'
  '';
in
writeTextFile {
  inherit name passthru derivationArgs;
  meta = {
    mainProgram = name;
  }
  // meta;
  executable = true;
  destination = "/bin/${name}";
  text = ''
    #!${nu} --no-config-file
    ${loadEnvironment}
    $env.PATH = ${runtimePath}${inheritedPath}
    ${text}
  '';
  checkPhase = if checkPhase == null then syntaxCheck else checkPhase;
}
