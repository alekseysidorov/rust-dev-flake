{
  pkgs,
  pkgs-unstable,
  runtimeInputs,
}:
{
  check-cargo-semver = pkgs.writeShellApplication {
    name = "run-semver-checks";
    runtimeInputs = [ pkgs-unstable.cargo-semver-checks ] ++ runtimeInputs;
    text = "cargo semver-checks";
  };

  check-cargo-publish = pkgs.writeShellApplication {
    name = "run-cargo-publish-checks";
    inherit runtimeInputs;
    text = ''
      cargo publish --workspace --all-features --dry-run
    '';
  };
}
