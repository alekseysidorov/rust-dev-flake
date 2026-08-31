# rust-dev-flake

[![Nix Flake](https://img.shields.io/badge/Nix-Flake-blue.svg)](https://nixos.org/nix/flakes)
[![Rust](https://img.shields.io/badge/Rust-stable-orange.svg)](https://www.rust-lang.org)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A collection of Nix helpers to simplify Rust project maintenance and ensure
reproducible tooling — both locally and in CI.

## Git hooks

Inside `flake-parts.lib.mkFlake`:

```nix
{
  imports = [ inputs.rust-dev-flake.flakeModules.gitHooks ];

  perSystem = { pkgs, system, ... }: {
    gitHooks = {
      pre-commit = pkgs.writeShellScript "pre-commit" ''
        exec nix build .#checks.${system}.formatter -L
      '';
      pre-push = pkgs.writeShellScript "pre-push" ''
        exec nix flake check -L
      '';
    };
  };
}
```

Run `nix run .#install-git-hooks` to install the configured scripts. Hooks from
different modules are merged by name. An empty map creates no installer;
importing the module does not modify `.git`.

## Packages

`diplomat-tool` is available through the default overlay and
`nix run .#diplomat-tool`. `nix flake check` builds it on the current system.

## Flake input layout

Group inputs by their role in the consuming project, in this order:

1. **Nix** — package sets and flake framework (`nixpkgs`, `flake-parts`).
2. **System configuration** — OS and user modules (`nix-darwin`,
   `home-manager`).
3. **Build** — toolchains and builders (`fenix`, `crane`).
4. **Development** — shared helpers, formatters and checks (`rust-dev-flake`,
   `treefmt-nix`).

Skip empty groups. Keep related inputs together and `follows` inside each input.
Group by purpose, not ownership or URL type. In `imports`, keep external modules
before local modules; preserve any order required by their behavior.

## License

MIT — see [LICENSE](LICENSE).
