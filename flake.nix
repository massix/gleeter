{
  description = "Fetch and display XKCD comics directly in the terminal";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) mkShell;
        gleamPackagesHash = "sha256-DIY9OA3ZigaVC2gxvwgCrF8rjNIraSy7mVqudp62x4M=";
        version = "1.3.1";
        pname = "gleeter";
        src = ./.;
        gleam-helper = pkgs.callPackage ./nix/gleam-helper.nix { };
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
        overlays = _: _: { gleeter = self.packages.${system}.gleeter; };
        packages = {
          gleeter = gleam-helper.buildGleamPackage {
            inherit pname version src gleamPackagesHash;
            rebar3Plugins = with pkgs.beamPackages; [ ex_doc pc hex ];

            doCheck = true;

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
              homepage = "https://github.com/massix/gleeter";
              license = licenses.mit;
              maintainers = [ maintainers.massimogengarelli ];
            };
          };
          default = self.packages.${system}.gleeter;
          version-file = pkgs.writeTextFile {
            name = "${pname}-version.txt";
            text = "${version}";
          };
        };
      });
}
