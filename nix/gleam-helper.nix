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

        nativeBuildInputs = [
          gleam
          pkgs.cacert
        ];
        src = builtins.filterSource (path: _: builtins.elem (baseNameOf path) [ "manifest.toml" "gleam.toml" ]) src;

        # This is a fixed-output derivation that just stages downloaded package
        # sources for later use, so it must not be run through the fixup phase.
        # Doing so would patch script interpreters (e.g. quic's quic_call.sh)
        # with store paths, which is not allowed in a fixed-output derivation.
        dontFixup = true;

        buildPhase = ''
          export HOME=$PWD
          # Gleam 1.18 builds its HTTP client with rustls-platform-verifier,
          # which on Linux loads CA certificates from the system trust store.
          # The nix sandbox has no such store, so point it at the nixpkgs CA
          # bundle instead (honoured by rustls-native-certs via openssl-probe).
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          gleam deps download
          # Canonicalize packages.toml: gleam writes its entries in a
          # non-deterministic order, which would make the fixed-output hash of
          # this derivation unstable. Sort the entries within each table while
          # preserving the table structure so the file stays valid TOML.
          awk '
            /^\[/ { sec++; print sprintf("%03d0", sec) "|" $0; next }
            NF    { print sprintf("%03d1", sec) "|" $0 }
          ' build/packages/packages.toml | sort | sed 's/^[0-9][0-9][0-9][01]|//' > packages.toml.canon
          mv packages.toml.canon build/packages/packages.toml
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

      nativeBuildInputs = [
        gleam
        (pkgs.beam27Packages.rebar3WithPlugins {
          plugins = rebar3Plugins;
        })
        gleamPackages
      ] ++ nativeBuildInputs;

      propagatedBuildInputs = [ pkgs.beam27Packages.erlang ] ++ propagatedBuildInputs;

      configurePhase = ''
        cp --recursive ${gleamPackages}/build .
        chmod -R 0755 build
      '';
    } // rest);
}
