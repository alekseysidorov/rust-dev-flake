{ inputs }:

final: prev:
let
  pkgs = final;
  rustDev = import ./lib/rustDev { inherit inputs; };
  gitHooks = import ./lib/git-hooks.nix;
in
{
  rustDev = {
    mkCraneLib = args: rustDev.mkCraneLib (args // { inherit pkgs; });
    mkRustDevHelpers = args: rustDev.mkRustDevHelpers (args // { inherit pkgs; });
  };
  gitHooks = gitHooks.mkLib final.buildPackages;
  /*
    Creates a Nushell script application.

    Similar to [writeShellScriptBin][1] but targets `.nu` scripts instead of shell scripts.
    The script is loaded via `builtins.readFile`, so it must be passed as a path to the source file (not its content).

    [1]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/manual.xml

    # Arguments
    - `name` — name of the application and executable; becomes `$out/bin/<name>`
    - `script` — path to the `.nu` script file
    - `runtimeInputs` — additional packages added to the beginning of `PATH`; defaults to `[ ]`
    - `env` — Nix attribute set whose keys become exported environment variables (e.g. `{ VAR = "value"; }`)
    - `meta` — arbitrary attribute set merged into the result (typically `{ description; mainProgram; })`

    # Example
    ```nix
    writeNuApplication {
      name = "vpn-peer";
      script = ./tools/vpn-peer.nu;
      runtimeInputs = with pkgs; [ sops age ];
      env = { SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt"; };
      meta.mainProgram = "vpn-peer";sha256-lRVP1vkY2pVr9aH/Q8wYVi/gzD4IBSKw42kUaV3ZjAE=
    }
    ```
  */
  writeNuApplication =
    {
      name,
      script,
      runtimeInputs ? [ ],
      env ? { },
      meta ? { },
    }:
    let
      runtimePath = final.lib.makeBinPath runtimeInputs;
      nuScript = final.writeText "${name}.nu" (builtins.readFile script);
      # Expose env vars as shell exports. Nu doesn't have a way to set env vars for scripts, so we have to do it ourselves.
      envExports = map (key: "export ${key}=${env.${key}}") (builtins.attrNames env);
    in
    final.writeShellScriptBin name ''
      export PATH="${runtimePath}:$PATH"
      ${builtins.concatStringsSep "\n" envExports}
      exec "${final.nushell}/bin/nu" "${nuScript}" "$@"
    ''
    // meta;

  # Extra packages
  diplomat-tool = final.callPackage ./pkgs/diplomat-tool.nix { };
}
