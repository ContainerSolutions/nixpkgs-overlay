self: super: {
  container-solutions = {
    dockerTools = import ./docker-tools.nix self super;
  };
}
