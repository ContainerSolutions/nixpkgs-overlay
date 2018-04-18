with (import <nixpkgs> {});
rec {
  tool = callPackage ./google-cloud-sdk.nix {
    stdenv = stdenv;
    lib = lib;
    fetchurl = fetchurl;
    makeWrapper = makeWrapper;
    python = python;
    cffi = python27Packages.cffi;
    cryptography = python27Packages.cryptography;
    pyopenssl = python27Packages.pyopenssl;
    crcmod = python27Packages.crcmod;
    google-compute-engine = google-compute-engine;
  };
}
