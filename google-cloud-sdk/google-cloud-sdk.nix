# Make sure that the "with-gce" flag is set when building `google-cloud-sdk`
# for GCE hosts. This flag prevents "google-compute-engine" from being a
# default dependency which is undesirable because this package is
#
#   1) available only on GNU/Linux (requires `systemd` in particular)
#   2) intended only for GCE guests (and is useless elsewhere)
#   3) used by `google-cloud-sdk` only on GCE guests
#

{ stdenv, lib, fetchurl, makeWrapper, python, cffi, cryptography, pyopenssl,
  crcmod, google-compute-engine, with-gce ? false }:

let
  pythonInputs = [ cffi cryptography pyopenssl crcmod ]
                 ++ lib.optional (with-gce) google-compute-engine;
  pythonPath = lib.makeSearchPath python.sitePackages pythonInputs;

  baseUrl = "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads";
  sources = name: system: {
    x86_64-darwin = {
      url = "${baseUrl}/${name}-darwin-x86_64.tar.gz";
      sha256 = "0c4jj580f7z6phiw4zhd32dlf4inkrxy3cig6ng66fi4zi6vnpc9";
    };

    x86_64-linux = {
      url = "${baseUrl}/${name}-linux-x86_64.tar.gz";
      sha256 = "37223616327ec82e33d0b07b77f6d641e4c031a786ea945f21e67f78fc67d1c1";
    };
  }.${system};

in stdenv.mkDerivation rec {
  name = "google-cloud-sdk-${version}";
  version = "198.0.0";

  src = fetchurl (sources name stdenv.system);

  buildInputs = [ python makeWrapper ];

  phases = [ "installPhase" "fixupPhase" ];

  installPhase = ''
    mkdir -p "$out"
    tar -xzf "$src" -C "$out" google-cloud-sdk

    mkdir $out/google-cloud-sdk/lib/surface/alpha
    cp ${./alpha__init__.py} $out/google-cloud-sdk/lib/surface/alpha/__init__.py

    mkdir $out/google-cloud-sdk/lib/surface/beta
    cp ${./beta__init__.py} $out/google-cloud-sdk/lib/surface/beta/__init__.py

    # create wrappers with correct env
    for program in gcloud bq gsutil git-credential-gcloud.sh; do
        programPath="$out/google-cloud-sdk/bin/$program"
        binaryPath="$out/bin/$program"
        wrapProgram "$programPath" \
            --set CLOUDSDK_PYTHON "${python}/bin/python" \
            --prefix PYTHONPATH : "${pythonPath}"

        mkdir -p $out/bin
        ln -s $programPath $binaryPath
    done

    # disable component updater and update check
    substituteInPlace $out/google-cloud-sdk/lib/googlecloudsdk/core/config.json \
      --replace "\"disable_updater\": false" "\"disable_updater\": true"
    echo "
    [component_manager]
    disable_update_check = true" >> $out/google-cloud-sdk/properties

    # setup bash completion
    mkdir -p "$out/etc/bash_completion.d/"
    mv "$out/google-cloud-sdk/completion.bash.inc" "$out/etc/bash_completion.d/gcloud.inc"

    # This directory contains compiled mac binaries. We used crcmod from
    # nixpkgs instead.
    rm -r $out/google-cloud-sdk/platform/gsutil/third_party/crcmod
  '';

  meta = with stdenv.lib; {
    description = "Tools for the google cloud platform";
    longDescription = "The Google Cloud SDK. This package has the programs: gcloud, gsutil, and bq";
    # This package contains vendored dependencies. All have free licenses.
    license = licenses.free;
    homepage = "https://cloud.google.com/sdk/";
    maintainers = with maintainers; [ stephenmw zimbatm ];
    platforms = [ "x86_64-linux" "x86_64-darwin" ];
  };
}
