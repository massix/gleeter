{ pkgs
, lib
, stdenv
, gleam
}:
{
  buildGleamPackage =
    { src
    , pname
    , version
    , nativeBuildInputs ? [ ]
    , rebar3Plugins ? [ ]
    , propagatedBuildInputs ? [ ]
    , gleamPackagesHash ? lib.fakeHash
    , ...
    }@rest:
    let
      gleamPackages = stdenv.mkDerivation {
        pname = "${pname}-gleam-packages";
        version = "${version}";

        nativeBuildInputs = with pkgs; [ gleam ];
        src = builtins.filterSource (path: _: builtins.elem (baseNameOf path) [ "manifest.toml" "gleam.toml" ]) src;

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
        outputHash = gleamPackagesHash;
      };
    in
    stdenv.mkDerivation ({
      inherit pname version src;

      nativeBuildInputs = with pkgs; [
        gleam
        (rebar3WithPlugins {
          plugins = rebar3Plugins;
        })
        gleamPackages
      ] ++ nativeBuildInputs;

      propagatedBuildInputs = [ pkgs.erlang_27 ] ++ propagatedBuildInputs;

      configurePhase = ''
        cp --recursive ${gleamPackages}/build .
        chmod -R 0755 build
      '';
    } // rest);
}
