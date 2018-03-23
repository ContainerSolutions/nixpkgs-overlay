# Nixpkgs Overlays in use at Container Solutions

- [Docker Tools](./docker-tools.nix)
- [Minikube](./minikube). Also see the and the relevant lines in [default.nix](./default.nix) for which versions we have backported.
  Example usage: `$(nix-build shell.nix -A container-solutions.minikube-k8s-1_7_5)/bin/minikube start`
