{ stdenv, lib, fetchurl, applyPatches, fetchpatch, python3, nbPython3Packages, pkgs }:

let
  version = "0.9.1";
  src = applyPatches {
    src = fetchurl {
      url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/v${version}.tar.gz";
      sha256 = "0a8jlzi3ll1dw60fwnqs5awmcfxdjynh6i1gfmcc29qhwjpx5djl";
    };
    patches = [
      (fetchpatch {
        # https://github.com/JoinMarket-Org/joinmarket-clientserver/pull/999
        name = "improve-genwallet";
        url = "https://patch-diff.githubusercontent.com/raw/JoinMarket-Org/joinmarket-clientserver/pull/999.patch";
        sha256 = "etlbi0yhb4X5EAPUerIIAXU6l7EeB9O2c07QaXxCEAg=";
      })
    ];
  };

  runtimePackages = with nbPython3Packages; [
    joinmarketbase
    joinmarketclient
    joinmarketbitcoin
    joinmarketdaemon
    matplotlib # for ob-watcher
  ];

  pythonEnv = python3.withPackages (_: runtimePackages);
in
stdenv.mkDerivation {
  pname = "joinmarket";
  inherit version src;

  buildInputs = [ pythonEnv ];

  installPhase = ''
    mkdir -p $out/bin

    # add-utxo.py -> bin/jm-add-utxo
    cpBin() {
      cp scripts/$1 $out/bin/jm-''${1%.py}
    }

    cp scripts/joinmarketd.py $out/bin/joinmarketd
    cpBin add-utxo.py
    cpBin convert_old_wallet.py
    cpBin receive-payjoin.py
    cpBin sendpayment.py
    cpBin sendtomany.py
    cpBin tumbler.py
    cpBin wallet-tool.py
    cpBin yg-privacyenhanced.py
    cpBin genwallet.py

    chmod +x -R $out/bin
    patchShebangs $out/bin

    ## ob-watcher
    obw=$out/libexec/joinmarket-ob-watcher
    install -D scripts/obwatch/ob-watcher.py $obw/ob-watcher
    patchShebangs $obw/ob-watcher
    ln -s $obw/ob-watcher $out/bin/jm-ob-watcher

    # These files must be placed in the same dir as ob-watcher
    cp -r scripts/obwatch/{orderbook.html,sybil_attack_calculations.py,vendor} $obw
  '';
}
