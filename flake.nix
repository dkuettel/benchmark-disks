{
  description = "benchmark disks";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      unstable,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        name = "bench";

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          #   overlays = [
          #     (final: prev: {
          #       cudaPackages = prev.lib.recurseIntoAttrs prev.cudaPackages_13_0;
          #     })
        };
        upkgs = import unstable {
          inherit system;
          config.allowUnfree = true;
        };
        inherit (pkgs) lib;
        inherit (builtins) map;

        # see https://www.python.org/downloads/ for release cycles
        # and https://search.nixos.org/packages?channel=unstable&query=python31
        python = pkgs.python314;

        uv = pkgs.writeScriptBin "uv" ''
          #!${pkgs.zsh}/bin/zsh
          set -eu -o pipefail
          UV_PYTHON=${python}/bin/python ${pkgs.uv}/bin/uv --no-python-downloads $@
        '';
        # TODO the below is only true for `uv run`, when building with pyproject-nix it still fails, the uv build system still doesnt support it?
        #      but it does work when using a namespace package and a new file inside, better than nothing
        # NOTE for using single files and/or namespace packages
        # > uv init --app --package name
        # for one file, change to: src/name.py
        # for a namespace, change to: src/name/app.py or something
        # and adapt [project.scripts] if the names or qualifications changed
        # plus add
        #   [tool.uv.build-backend]
        #   namespace = true
        # probably not needed anymore, but before we needed:
        #   [tool.hatch.build.targets.wheel]
        #   packages = ["src/name.py"]  # if you use single files, but needs old build system below
        #   [build-system]
        #   requires = ["hatchling"]
        #   build-backend = "hatchling.build"

        # TODO add pyproject template too? like the ignore stuff for pyright?

        # NOTE trying a way to run all python linters/lsps to have some comparison
        # usually only one is really installed so that nvim picks that one
        lint = pkgs.writeScriptBin "lint" ''
          #!${pkgs.zsh}/bin/zsh
          set -eu -o pipefail

          fail=no

          echo
          echo '[basedpyright]'
          ${pkgs.basedpyright}/bin/basedpyright $h/src || fail=yes

          echo
          echo '[ty]'
          ${upkgs.ty}/bin/ty check $h/src || fail=yes

          echo
          echo '[pyrefly]'
          ${upkgs.pyrefly}/bin/pyrefly check $h/src || fail=yes

          [[ $fail == no ]]
        '';

        devPkgs = (
          [
            uv
            python
            lint
          ]
          ++ (with pkgs; [
            ruff
            # basedpyright
            nil # nix language server
            nixfmt # nix formatter
          ])
          ++ (with upkgs; [
            ty # might be ok
          #   pyrefly # was a bit worse than ty?
          ])
        );

        # TODO there is more to improve, see after geom/flake.nix works
        devLibs = with pkgs; [
          stdenv.cc.cc
          # zlib  # eg, needed for numpy
          # libglvnd
          # libX11
          # glib
          # eigen
          # cudatoolkit  # version needs to fit with what pytorch was compiled for, see overlay at pkgs for version
        ];

        devLdLibs = pkgs.buildEnv {
          name = "${name}-dev-ld-libs";
          paths = map (lib.getOutput "lib") devLibs;
        };

        devEnv = pkgs.buildEnv {
          name = "${name}-dev-env";
          paths = devPkgs ++ devLibs;
        };

      in
      {
        devShells.default = pkgs.mkShellNoCC {
          packages = [ devEnv ];
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [ devLdLibs ]}";
          shellHook = ''
            if [[ -v h ]]; then
              export PATH=$h/bin:$PATH;
            else
              echo 'Project root env var h is not set.' >&2
            fi
          '';
        };
      }
    );
}
