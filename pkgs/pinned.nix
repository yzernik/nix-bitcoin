let
  nixpkgsPinned = import ./nixpkgs-pinned.nix;
  nixpkgsStable = import nixpkgsPinned.nixpkgs { config = {}; overlays = []; };
  nixpkgsUnstable = import nixpkgsPinned.nixpkgs-unstable { config = {}; overlays = []; };
  nixBitcoinPkgsStable = import ./. { pkgs = nixpkgsStable; };
  nixBitcoinPkgsUnstable = import ./. { pkgs = nixpkgsUnstable; };
in
{
  inherit (nixpkgsUnstable)
    bitcoin
    bitcoind
    clightning
    lnd
    nbxplorer
    btcpayserver;

  stable = nixBitcoinPkgsStable;
  unstable = nixBitcoinPkgsUnstable;
}
