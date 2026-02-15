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
      pkgs = import nixpkgs { 
        inherit system;
        config.allowUnfree = true;  # Allow CUDA for ollama-cuda
      };

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
          
          # Open IRC port in firewall
          networking.firewall.allowedTCPPorts = [ 6667 ];

          # User setup
          users.users.nixos = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            initialPassword = "nixos";
            linger = true;  # Enable systemd user services at boot
          };
          security.sudo.wheelNeedsPassword = false;
          services.getty.autologinUser = "nixos";

          # Enable SSH for debugging
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
            settings.PasswordAuthentication = true;
          };

          # IRC server for control (ngircd) - minimal config, no auth, listen on all interfaces
          # Disable ident and DNS to avoid connection delays from NAT
          services.ngircd = {
            enable = true;
            config = ''
              [Global]
              Name = irc.openclaw.local
              AdminInfo1 = OpenClaw VM
              AdminInfo2 = Local Control
              AdminEMail = root@localhost
              Listen = 0.0.0.0
              
              [Options]
              PAM = no
              RequireAuthPing = no
              Ident = no
              DNS = no
            '';
          };

          # Ollama with CUDA - use pre-fetched model
          services.ollama = {
            enable = true;
            package = pkgs.ollama-cuda;
            models = "/var/lib/ollama/models";
            environmentVariables = {
              OLLAMA_NO_CLOUD = "1";
            };
          };

          # Install model blobs into ollama's structure
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

          # Home-manager + OpenClaw with declarative config
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.nixos = {
            home.stateVersion = "26.05";
            imports = [ nix-openclaw.homeManagerModules.openclaw ];
            
            # Declarative OpenClaw configuration
            programs.openclaw = {
              enable = true;
              
              # Enable systemd service to start automatically
              systemd.enable = true;
              
              # Main config (schema-typed)
              config = {
                gateway = {
                  mode = "local";
                  port = 18789;
                  bind = "loopback";
                  auth = {
                    mode = "token";
                    token = "da60c496bba969bd8e1a3ff6ae7b177eb8cf47033f35bb05";
                  };
                };
                
                # Configure local ollama model (let ollama report context window)
                models = {
                  mode = "merge";
                  providers = {
                    "custom-127-0-0-1-11434" = {
                      auth = "api-key";
                      # Ollama doesn't require auth for local connections, but OpenClaw
                      # requires a non-empty apiKey at runtime. The value is ignored by Ollama.
                      apiKey = "fake-api-key";
                      baseUrl = "http://127.0.0.1:11434/v1";
                      api = "openai-completions";
                      models = [{
                        id = "llama3.2:3b";
                        name = "llama3.2:3b (Local)";
                        reasoning = false;
                        input = [ "text" ];
                        cost = {
                          input = 0;
                          output = 0;
                          cacheRead = 0;
                          cacheWrite = 0;
                        };
                      }];
                    };
                  };
                };
                
                agents = {
                  defaults = {
                    workspace = "/home/nixos/.openclaw/workspace";
                    model = {
                      primary = "custom-127-0-0-1-11434/llama3.2:3b";
                    };
                  };
                };
                
                # IRC configuration
                channels = {
                  irc = {
                    enabled = true;
                    host = "localhost";
                    port = 6667;
                    tls = false;
                    nick = "openclaw";
                    username = "openclaw";
                    realname = "OpenClaw";
                    channels = [ "#openclaw" ];
                    dmPolicy = "open";
                    allowFrom = [ "*" ];  # Required for dmPolicy="open"
                    groupPolicy = "open";
                    groups = {
                      "*" = {
                        requireMention = false;
                        allowFrom = [ "*" ];
                      };
                    };
                  };
                };
              };
            };

            # Ensure the openclaw-gateway service is enabled and starts automatically
            systemd.user.services.openclaw-gateway.Install.WantedBy = lib.mkForce [ "default.target" ];
          };

          # VM configuration
          virtualisation = {
            memorySize = 8192;  # 8GB default
            cores = 4;          # 4 cores default
            graphics = false;

            # Port forward IRC and SSH from host to guest
            forwardPorts = [
              { from = "host"; host.port = 6667; guest.port = 6667; }
              { from = "host"; host.port = 2222; guest.port = 22; }
            ];
            
            # Restrict network access (guest can only reach host gateway)
            restrictNetwork = true;
            
            qemu.options = [
              "-nographic"
              "-serial mon:stdio"
            ];
          };

          system.stateVersion = "26.05";
        })
      ];
    };
  };
}
