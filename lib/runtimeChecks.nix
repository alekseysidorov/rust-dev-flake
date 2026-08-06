# runtimeChecks
#
# Shell script derivations for operations that require network access and
# therefore cannot run inside the Nix sandbox. Expose them as `packages` so
# they can be invoked with `nix run .#<name>`.
#
# All scripts receive `runtimeInputs` in their PATH — pass at minimum your
# Rust toolchain and any C libraries your crate links against.
#
# Example (in your flake):
#   packages = {
#     inherit (rustDev.runtimeChecks)
#       check-cargo-semver
#       check-cargo-publish
#       benchmarks;
#   };
{
  pkgs,
  runtimeInputs,
}:
{
  # Runs `cargo semver-checks` to detect accidental breaking API changes.
  # Run with: nix run .#check-cargo-semver
  check-cargo-semver = pkgs.writeShellApplication {
    name = "run-semver-checks";
    runtimeInputs = [ pkgs.cargo-semver-checks ] ++ runtimeInputs;
    text = ''
      cargo semver-checks
    '';
  };

  # Runs `cargo publish --dry-run` to verify the crate is publishable:
  # metadata is valid, all files are included, and dependencies resolve.
  # Does not actually upload anything to crates.io.
  # Run with: nix run .#check-cargo-publish
  check-cargo-publish = pkgs.writeShellApplication {
    name = "run-cargo-publish-checks";
    inherit runtimeInputs;
    text = ''
      cargo publish --workspace --all-features --dry-run
    '';
  };

  # Runs `cargo bench` with all features enabled.
  # Useful for local performance profiling and catching regressions.
  # Run with: nix run .#benchmarks
  benchmarks = pkgs.writeShellApplication {
    name = "run-benchmarks";
    inherit runtimeInputs;
    text = ''
      cargo bench --workspace --all-features
    '';
  };
}
