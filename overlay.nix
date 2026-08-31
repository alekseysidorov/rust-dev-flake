{ inputs }:

final: prev:
let
  pkgs = final;
  rustDev = import ./lib/rustDev { inherit inputs; };
  gitHooks = import ./lib/git-hooks.nix;
in
{
  # Preserve this package set's overlays and cross-compilation configuration.
  rustDev = {
    mkCraneLib = args: rustDev.mkCraneLib (args // { inherit pkgs; });
    mkRustDevHelpers = args: rustDev.mkRustDevHelpers (args // { inherit pkgs; });
  };
  # Hook installers run on the build machine, not the cross-compilation target.
  gitHooks = gitHooks.mkLib final.buildPackages;

  /*
    Apply the root .gitignore before selecting a subdirectory.
    projectRoot: project directory containing .gitignore; nested files are not read.
    sourceDir: directory relative to projectRoot, or "." (default) for the whole filtered project.

    Example: projectSource { projectRoot = ./.; sourceDir = "crates"; }
  */
  projectSource =
    {
      projectRoot,
      sourceDir ? ".",
    }:
    let
      source = final.nix-gitignore.gitignoreSource [ ] projectRoot;
    in
    if sourceDir == "." then source else "${source}/${sourceDir}";

  # name: store filename; text: Nu code without a shebang. Returns an executable file for hooks.
  writeNuShellScript =
    name: text:
    final.writeScript name ''
      #!${final.nushell}/bin/nu
      ${text}
    '';
  /*
    Like writeShellApplication, but text is Nu code and runs without a Bash wrapper.
    runtimeInputs prepend PATH; inheritPath keeps the caller's PATH by default.
    runtimeEnv contains environment values, not secrets: they enter the Nix store.
    Syntax is checked without executing the script; checkPhase can override this.
  */
  writeNuShellApplication =
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
      # Load data rather than interpolating environment values into executable Nu code.
      environment = final.writeText "${name}-env.json" (
        builtins.toJSON (final.lib.mapAttrs (_: value: toString value) runtimeEnv)
      );
    in
    final.writeTextFile {
      inherit name passthru derivationArgs;
      meta = {
        mainProgram = name;
      }
      // meta;
      executable = true;
      destination = "/bin/${name}";
      text = ''
        #!${final.nushell}/bin/nu --no-config-file
        ${final.lib.optionalString (runtimeEnv != null) "load-env (open ${environment})"}
        $env.PATH = ${
          builtins.toJSON (map (pkg: "${final.lib.getBin pkg}/bin") runtimeInputs)
        }${final.lib.optionalString inheritPath " ++ ($env.PATH? | default [])"}
        ${text}
      '';
      checkPhase =
        if checkPhase != null then
          checkPhase
        else
          ''
            target="$target" ${final.nushell}/bin/nu --no-config-file -c 'nu-check --debug $env.target | if not $in { exit 1 }'
          '';
    };

  # Extra packages
  diplomat-tool = final.callPackage ./pkgs/diplomat-tool.nix { };
}
