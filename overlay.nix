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
  writeNuShellApplication = final.callPackage ./lib/write-nu-shell-application.nix { };

  # Extra packages
  diplomat-tool = final.callPackage ./pkgs/diplomat-tool.nix { };
}
