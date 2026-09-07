{
  nix-gitignore,
}:

/*
  Apply the root .gitignore before selecting a subdirectory.
  projectRoot: project directory containing .gitignore; nested files are not read.
  sourceDir: directory relative to projectRoot, or "." (default) for the whole filtered project.

  Example: projectSource { projectRoot = ./.; sourceDir = "crates"; }
*/
{
  projectRoot,
  sourceDir ? ".",
}:
let
  source = nix-gitignore.gitignoreSource [ ] projectRoot;
in
if sourceDir == "." then source else "${source}/${sourceDir}"
