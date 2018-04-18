self: super: {
  container-solutions = {
    dockerTools = import ./docker-tools.nix self super;

    minikube         = self.container-solutions.minikube-k8s-1_9;
    minikube-k8s-1_9 = self.container-solutions.minikube-k8s-1_9_0;
    minikube-k8s-1_7 = self.container-solutions.minikube-k8s-1_7_5;
  
    minikube-k8s-1_9_0 = super.callPackage ./minikube {
      inherit (self.darwin.apple_sdk.frameworks) vmnet;
    };
  
    minikube-k8s-1_7_5 = super.callPackage ./minikube {
      localkube-version = "1.7.5";
      inherit (self.darwin.apple_sdk.frameworks) vmnet;
    };

    google-cloud-sdk = super.callPackage ./google-cloud-sdk {
      inherit self;
    };
  };
}
