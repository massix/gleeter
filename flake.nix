{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ erlang_27 rebar3 ];
      };
      overlays.${system} = _: _: { gleeter = self.packages.${system}.default; };
      packages.${system}.default = pkgs.stdenv.mkDerivation rec {
        pname = "gleeter";
        version = "1.0.0";

        gleamPackages = pkgs.stdenv.mkDerivation {
          inherit version;
          pname = "${pname}-gleam-packages";

          nativeBuildInputs = with pkgs; [ gleam rebar3 ];
          src = builtins.filterSource
            (path: _: builtins.elem (baseNameOf path) [ "manifest.toml" "gleam.toml" ]) ./.;

          buildPhase = ''
            mkdir -p $out
            HOME=$PWD gleam deps download
          '';

          installPhase = ''
            mkdir -p $out/build/
            cp -r build/packages $out/build/
          '';

          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-Gr90dYn6fnktoPHXMxkwkQDSEMRjR29CPsnjZO7hJZU=";
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
          ls -laR .
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
