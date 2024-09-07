{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      inherit (pkgs) stdenv mkShell;
    in
    {
      devShells.${system}.default = mkShell {
        packages = with pkgs; [ erlang_27 rebar3 gleam ];
      };
      overlays.${system} = _: _: { gleeter = self.packages.${system}.default; };
      packages.${system}.default = stdenv.mkDerivation rec {
        pname = "gleeter";
        version = "1.0.0";

        gleamPackages = stdenv.mkDerivation {
          inherit version;
          pname = "${pname}-gleam-packages";

          nativeBuildInputs = with pkgs; [ gleam ];
          src = builtins.filterSource
            (path: _: builtins.elem (baseNameOf path) [ "manifest.toml" "gleam.toml" ]) ./.;

          buildPhase = ''
            mkdir -p $out
            HOME=$PWD gleam deps download
            grep -v '\[packages\]' build/packages/packages.toml | sort > packages.toml
            echo -e "[packages]\n" > build/packages/packages.toml
            cat packages.toml >> build/packages/packages.toml
            rm packages.toml
          '';

          installPhase = ''
            mkdir -p $out/build/
            cp --recursive build/packages $out/build/
          '';

          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-CS4tBFm4dSgd4zRCNJ7+6JwH+AYnAVGuxSzmwZxjDTE=";
        };

        src = builtins.filterSource
          (path: _: ! builtins.elem (baseNameOf path) [ "build" ".git" ".direnv" ".envrc" ])
          ./.;

        nativeBuildInputs = with pkgs; [ gleam rebar3 which gleamPackages ];
        buildInputs = with pkgs; [ erlang_27 ];

        doCheck = true;

        configurePhase = ''
          cp -r ${gleamPackages}/build build
          chmod -R 0755 build
        '';

        checkPhase = ''
          HOME=$PWD make test
        '';

        buildPhase = ''
          runHook preBuildHook
          HOME=$PWD make package
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
          homepage = "https://github.com/massix/gleeter.git";
          license = licenses.mit;
          maintainers = [ maintainers.massimogengarelli ];
        };
      };
      app.${system}.default = self.packages.${system}.default;
    };
}
