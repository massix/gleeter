{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) stdenv mkShell;
        fixed-output-hash = "sha256-DIY9OA3ZigaVC2gxvwgCrF8rjNIraSy7mVqudp62x4M=";
        version = "1.2.0";
        pname = "gleeter";
        gleamPackages = stdenv.mkDerivation {
          inherit version;
          pname = "${pname}-gleam-packages";

          nativeBuildInputs = with pkgs; [ gleam ];
          src = builtins.filterSource
            (path: _: builtins.elem (baseNameOf path) [ "manifest.toml" "gleam.toml" ]) ./.;

          buildPhase = ''
            export HOME=$PWD
            gleam deps download
            grep -v '\[packages\]' build/packages/packages.toml | sort > packages.toml
            echo -e "[packages]\n" > build/packages/packages.toml
            cat packages.toml >> build/packages/packages.toml
            rm packages.toml
          '';

          installPhase = ''
            runHook preInstallHook
            mkdir -p $out
            cp --recursive build $out/
            runHook postInstallHook
          '';

          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = fixed-output-hash;
        };

      in
      {
        devShells.default = mkShell {
          packages = with pkgs; [
            erlang_27
            beam27Packages.rebar3
            gleam
            sqlite
          ];
        };
        overlays = _: _: { gleeter = self.packages.${system}.default; };
        packages.default = stdenv.mkDerivation rec {
          inherit pname version;

          src = builtins.filterSource
            (path: _: ! builtins.elem (baseNameOf path) [ "build" ".git" ".direnv" ".envrc" ])
            ./.;

          nativeBuildInputs = with pkgs; [
            gleam
            (rebar3WithPlugins {
              plugins = with pkgs.beamPackages; [
                ex_doc
                pc
                hex
              ];
            })
            gleamPackages
          ];

          buildInputs = with pkgs; [
            erlang_27
          ];

          doCheck = true;

          configurePhase = ''
            cp --recursive ${gleamPackages}/build .
            chmod -R 0755 build
          '';

          checkPhase = ''
            HOME=$PWD make test
          '';

          buildPhase = ''
            runHook preBuildHook
            HOME=$PWD gleam export erlang-shipment
            runHook postBuildHook
          '';

          installPhase = ''
            runHook preInstallHook
            mkdir -p $out/opt/gleeter/
            mkdir -p $out/bin/
            cp -r build/erlang-shipment/* $out/opt/gleeter/
            substituteInPlace $out/opt/gleeter/entrypoint.sh \
              --replace erl ${pkgs.erlang_27}/bin/erl
            cp scripts/gleeter $out/bin/gleeter
            substituteInPlace $out/bin/gleeter \
              --replace /opt/gleeter $out/opt/gleeter
            runHook postInstallHook
          '';

          meta = with pkgs.lib; {
            description = "Fetch and display XKCD comics directly in the terminal";
            mainProgram = "gleeter";
            homepage = "https://github.com/massix/gleeter";
            license = licenses.mit;
            maintainers = [ maintainers.massimogengarelli ];
          };
        };
        app.default = self.packages.default;
      });
}
