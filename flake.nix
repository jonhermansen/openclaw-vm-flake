{
  description = "Minimal OpenClaw VM with isolated environment";

  inputs = {
    nix-openclaw.url = "github:openclaw/nix-openclaw";
  };

  outputs = { self, nix-openclaw }: 
    let
      nixpkgs = nix-openclaw.inputs.nixpkgs;
      home-manager = nix-openclaw.inputs.home-manager;
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
          
          # Disable networking
          networking.useDHCP = false;
          networking.interfaces = {};
          networking.firewall.enable = true;
          networking.networkmanager.enable = false;
          networking.wireless.enable = false;
          
          # User setup
          users.users.nixos = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            initialPassword = "nixos";
          };
          security.sudo.wheelNeedsPassword = false;
          services.getty.autologinUser = "nixos";
          
          # Ollama with CUDA (starts automatically)
          services.ollama = {
            enable = true;
            package = pkgs.ollama-cuda;
            loadModels = [ "llama3.2:3b" ];
          };
          
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
            
            # Completely disable networking
            qemu.networkingOptions = lib.mkForce [];
            
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
