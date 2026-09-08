{
  description = "Fetch and display XKCD comics directly in the terminal";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux" ] (system:
      let
        pkgs =
          if system == "x86_64-darwin" then
            import nixpkgs-stable { inherit system; }
          else import nixpkgs { inherit system; };
        inherit (pkgs) mkShell;
        gleamPackagesHash = "sha256-FTPZ+ZophA0ZdnlqGx0fkU7BwxFayQX33wek4wxMD98=";
        version = "1.4.0";
        pname = "gleeter";
        src = ./.;
        gleam-helper = pkgs.callPackage ./nix/gleam-helper.nix { };
      in
      {
        devShells.default = mkShell {
          packages = with pkgs; [
            beam27Packages.erlang
            beam27Packages.rebar3
            gleam
            sqlite
          ];
        };
        overlays = _: _: { inherit (self.packages.${system}) gleeter; };
        packages = {
          gleeter = gleam-helper.buildGleamPackage {
            inherit pname version src gleamPackagesHash;
            rebar3Plugins = with pkgs.beam27Packages; [ ex_doc pc hex ];

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
                --replace erl ${pkgs.beam27Packages.erlang}/bin/erl
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
