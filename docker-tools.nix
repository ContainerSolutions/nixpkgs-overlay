self: super:
with self.pkgs;
with super.lib;
/*
  # Container Solutions's Docker Tools

  This file contains an alternative implementation of Docker Tools, which allow you to generate
  Docker Images from a Nix closure.

  The main difference with existing approaches, is that we have a one-on-one mapping of
  Nix store paths, and docker image layers.


  ## Provided functions

  `drv2oci-dir`:
    This creates a directory which has the same structure as `docker save $IMAGE | tar -xz`.
    The only subtile difference is that we include _symlinks_ to each individual layer.
    This means that a tar archive created directly from this directory will not be loadable in
    Docker. See the functions below on how to do that.

  `dir2tar`:
    which takes the output of `drv2oci-dir` as an input, and produces a .tar file that can be
    loaded in Docker.

  ## Examples
  ```
  # Extract image hash after it's loaded.
  $ IMAGE_ID=$(docker load < $(nix-build shell.nix -A container-solutions.dockerTools.examples.figlet-tar) | cut -d':' -f3)
  $ docker run --rm $IMAGE_ID
  ```
*/
let 
  # Creates a tar file that can be loaded with `docker load < $TAR_FILE`.
  # Note that we use the -h flag to follow symlinks, and remove them, such that the actual
  # content of each symlinked directory is added.
  dir2tar = dir: 
    runCommand "${dir.name}.tar" {}
               "tar -C ${dir} -chf $out .";

  # Create a directory containing the file structure of the uncompressed output of `docker save`.
  # One mayor diference is that the layers we refer to are _symlinks_.
  drv2oci-dir = drv: settings:
    let
      # Helper function to get the actual lines with content from a file
      contentLines = file: (splitString "\n" (fileContents file));

      # Read all the runtime references of `drv` into a Nix list.
      references = contentLines (writeReferencesToFile drv);

      # Turn a single runtime reference (store path) into a separate derivation that contains the layer directory.
      createLayer = reference:
        stdenv.mkDerivation {
          name = "docker-layer";

          buildInput = [ drv ];
      
          buildCommand = ''
            mkdir $out
            tar -cf layer.tar ${reference}
            SHA256=$(sha256sum layer.tar | cut -d ' ' -f1)
            mkdir -p $out/$SHA256/
            mv layer.tar $out/$SHA256/layer.tar
            echo "1.0" > $out/$SHA256/VERSION
            echo "{\"id\":\"$SHA256\"}" > $out/$SHA256/json
          '';
        };

      # The file system layers
      layers = map createLayer references;


    # Find the content-addressable names of each layers.
    layer_ids = contentLines (runCommand "layer_ids" { inherit layers; } ''
      for layer_dir in $layers; do
        ls $layer_dir >> $out
      done
    '');

    # Build a config from the default settings and the layers.
    defaultSettings = 
      {
        architecture = "amd64";
        config = {
          Hostname = "";
          Domainname = "";
          User = "";
          AttachStdin  = false;
          AttachStdout = false;
          AttachStderr = false;
          Tty = false;
          OpenStdin =  false;
          StdinOnce = false;
          Env= [ ];
          Cmd = [ ];
          ArgsEscaped = true;
          Volumes = null;
          WorkingDir = "/";
          Entrypoint = null;
          OnBuild = [];
          Labels =  null;
        };
        os = "linux";
        rootfs = {
          type = "layers";
          diff_ids = [ ];
        };
      };
    config' = recursiveUpdate defaultSettings settings;
    config  = recursiveUpdate config' { rootfs.diff_ids = map (x: "sha256:${x}") layer_ids; };
    config_json = pkgs.writeText "config.json" (builtins.toJSON config);
    config_json_sha = fileContents (runCommand "config_json_sha" {} "sha256sum ${config_json} | cut -d ' ' -f1 > $out");

    layer_tar_files = map (x: "${x}/layer.tar") layer_ids;
    manifest = [{ Config = "${config_json_sha}.json"; Layers = layer_tar_files; }];
    manifest_json = pkgs.writeText "manifest.json" (builtins.toJSON manifest);

    in runCommand "${drv.name}-ocidir"  { buildInputs = [ drv ]; } ''
        mkdir $out

        for layer in ${concatStringsSep " " layers}; do
          ln -s $layer/* $out
        done

        cp ${config_json} $out/${config_json_sha}.json
        cp ${manifest_json} $out/manifest.json
    '';
in {
  inherit drv2ocidir dir2tar;

  examples = rec {
    hello-dir = drv2oci-dir self.pkgs.hello { config.Cmd = ["${self.pkgs.hello}/bin/hello"]; };
    hello-tar = dir2tar hello-dir;

    figlet-dir = drv2oci-dir self.pkgs.figlet { config.Cmd = ["${self.pkgs.figlet}/bin/figlet" "DockerTools"]; };
    figlet-tar = dir2tar figlet-dir;
  };
}
