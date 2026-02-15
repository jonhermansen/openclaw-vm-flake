{
  description = "Minimal OpenClaw VM with isolated environment";

  inputs = {
    nix-openclaw.url = "github:openclaw/nix-openclaw";
  };

  outputs = { self, nix-openclaw }: 
    let
      nixpkgs = nix-openclaw.inputs.nixpkgs;
      home-manager = nix-openclaw.inputs.home-manager;
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      
      # Fetch llama3.2:3b manifest and blobs into nix store
      llama32-3b-manifest = pkgs.fetchurl {
        url = "https://registry.ollama.ai/v2/library/llama3.2/manifests/3b";
        hash = "sha256-qAxPF6zVUmX+7EA8eu+GvgwlmDqyedg/O806u8tbi3I=";
      };
      llama32-3b-blob-1 = pkgs.fetchurl {
        url = "https://registry.ollama.ai/v2/library/llama3.2/blobs/sha256:34bb5ab01051a11372a91f95f3fbbc51173eed8e7f13ec395b9ae9b8bd0e242b";
        hash = "sha256-NLtasBBRoRNyqR+V8/u8URc+7Y5/E+w5W5rpuL0OJCs=";
      };
      llama32-3b-blob-2 = pkgs.fetchurl {
        url = "https://registry.ollama.ai/v2/library/llama3.2/blobs/sha256:dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff";
        hash = "sha256-3eWqP8X/wXF2tei9yC9YeySyZ4xsZhAb99p3r598zf8=";
      };
      llama32-3b-blob-3 = pkgs.fetchurl {
        url = "https://registry.ollama.ai/v2/library/llama3.2/blobs/sha256:966de95ca8a62200913e3f8bfbf84c8494536f1b94b49166851e76644e966396";
        hash = "sha256-lm3pXKimIgCRPj+L+/hMhJRTbxuUtJFmhR52ZE6WY5Y=";
      };
      llama32-3b-blob-4 = pkgs.fetchurl {
        url = "https://registry.ollama.ai/v2/library/llama3.2/blobs/sha256:fcc5a6bec9daf9b561a68827b67ab6088e1dba9d1fa2a50d7bbcc8384e0a265d";
        hash = "sha256-/MWmvsna+bVhpogntnq2CI4dup0foqUNe7zIOE4KJl0=";
      };
      llama32-3b-blob-5 = pkgs.fetchurl {
        url = "https://registry.ollama.ai/v2/library/llama3.2/blobs/sha256:a70ff7e570d97baaf4e62ac6e6ad9975e04caa6d900d3742d37698494479e0cd";
        hash = "sha256-pw/35XDZe6r05irG5q2ZdeBMqm2QDTdC03aYSUR54M0=";
      };
      llama32-3b-blob-6 = pkgs.fetchurl {
        url = "https://registry.ollama.ai/v2/library/llama3.2/blobs/sha256:56bb8bd477a519ffa694fc449c2413c6f0e1d3b1c88fa7e3c9d88d3ae49d4dcb";
        hash = "sha256-VruL1HelGf+mlPxEnCQTxvDh07HIj6fjydiNOuSdTcs=";
      };
    in {
    packages.x86_64-linux.default = self.nixosConfigurations.openclaw-vm.config.system.build.vm;
    
    apps.x86_64-linux.default = {
      type = "app";
      program = "${self.packages.x86_64-linux.default}/bin/run-openclaw-vm-vm";
    };

    nixosConfigurations.openclaw-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ modulesPath, pkgs, lib, ... }: {
          imports = [ 
            "${modulesPath}/virtualisation/qemu-vm.nix"
            home-manager.nixosModules.home-manager
          ];
          
          # Apply openclaw overlay to get pkgs.openclaw
          nixpkgs.overlays = [ nix-openclaw.overlays.default ];
          nixpkgs.config.allowUnfree = true;
          
          # Minimal system
          boot.kernelParams = [ "console=ttyS0" ];
          networking.hostName = "openclaw-vm";
          
          # User setup
          users.users.nixos = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            initialPassword = "nixos";
          };
          security.sudo.wheelNeedsPassword = false;
          services.getty.autologinUser = "nixos";
          
          # Ollama with CUDA - use pre-fetched model
          services.ollama = {
            enable = true;
            package = pkgs.ollama-cuda;
            models = "/var/lib/ollama/models";
          };
          
          # Install model blobs into ollama's structure: models/blobs/sha256-{digest}
          systemd.tmpfiles.rules = [
            "d /var/lib/ollama/models/manifests/registry.ollama.ai/library/llama3.2 0755 - - -"
            "d /var/lib/ollama/models/blobs 0755 - - -"
            "L+ /var/lib/ollama/models/manifests/registry.ollama.ai/library/llama3.2/3b - - - - ${llama32-3b-manifest}"
            "L+ /var/lib/ollama/models/blobs/sha256-34bb5ab01051a11372a91f95f3fbbc51173eed8e7f13ec395b9ae9b8bd0e242b - - - - ${llama32-3b-blob-1}"
            "L+ /var/lib/ollama/models/blobs/sha256-dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff - - - - ${llama32-3b-blob-2}"
            "L+ /var/lib/ollama/models/blobs/sha256-966de95ca8a62200913e3f8bfbf84c8494536f1b94b49166851e76644e966396 - - - - ${llama32-3b-blob-3}"
            "L+ /var/lib/ollama/models/blobs/sha256-fcc5a6bec9daf9b561a68827b67ab6088e1dba9d1fa2a50d7bbcc8384e0a265d - - - - ${llama32-3b-blob-4}"
            "L+ /var/lib/ollama/models/blobs/sha256-a70ff7e570d97baaf4e62ac6e6ad9975e04caa6d900d3742d37698494479e0cd - - - - ${llama32-3b-blob-5}"
            "L+ /var/lib/ollama/models/blobs/sha256-56bb8bd477a519ffa694fc449c2413c6f0e1d3b1c88fa7e3c9d88d3ae49d4dcb - - - - ${llama32-3b-blob-6}"
          ];
          
          # Home-manager + OpenClaw
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.nixos = {
            home.stateVersion = "26.05";
            imports = [ nix-openclaw.homeManagerModules.openclaw ];
            programs.openclaw.enable = true;
          };
          
          # VM configuration
          virtualisation = {
            memorySize = 32768;
            cores = 16;
            graphics = false;
            
            # Completely disable networking - no NIC hardware at all
            qemu.networkingOptions = lib.mkForce [];
            
            qemu.options = [
              "-nographic"
              "-serial mon:stdio"
              "-net none"  # Explicitly disable all network backends
            ];
          };
          
          system.stateVersion = "26.05";
        })
      ];
    };
  };
}
