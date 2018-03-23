{ pkgsPath ? <nixpkgs> }:
import pkgsPath {
  overlays = [ (import ./default.nix) ];
}
