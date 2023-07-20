{
  description = "Application packaged using poetry2nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.poetry2nix = {
    url = "github:nix-community/poetry2nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      system = "x86_64-linux";

      # import nixpkgs and poetry2nix functions
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ self.inputs.poetry2nix.overlay ];
      };
      
      # specify information about the package
      projectDir = self;
      python = pkgs.python310;
      
      # fix missing dependencies of external packages
      overrides = (self: super: import ./overrides.nix {
        inherit self super python;
        lib = nixpkgs.lib;
      });

      # generate development environment
      poetry-env = pkgs.poetry2nix.mkPoetryEnv {
        inherit projectDir python; 
        preferWheels = true;
        groups = [ "dev" "test" ];
      };

      python-app = pkgs.poetry2nix.mkPoetryApplication {
        inherit projectDir python;
        preferWheels = true;
        groups = [ ];
      };
      
      # download nltk-stopwords, an external dependency we are using
      nltk-stopwords = pkgs.fetchurl {
        url = "https://github.com/nltk/nltk_data/raw/5db857e6f7df11eabb5e5665836db9ec8df07e28/packages/corpora/stopwords.zip";
        sha256 = "sha256-FclBeYh0Jcob7cJlYIyrnyfWUCEfcJu5KeMgmQpLAdE=";
      };

      # declare, how the docker image shall be built
      docker-img = pkgs.dockerTools.buildImage {
        name = python-app.pname;
        tag = python-app.version;
        # unzip nltk-punkt and put it into a directory that nltk searches
        config = {
          Cmd = [
            "${pkgs.bash}/bin/sh" (pkgs.writeShellScript "runDocker.sh" ''
            ${pkgs.coreutils}/bin/mkdir -p /nltk_data/corpora &&
            ${pkgs.unzip}/bin/unzip ${nltk-stopwords} -d /nltk_data/corpora &&
            /bin/wlo-topic-assistant
          '')
          ];
          WorkingDir = "/";
        };
        # copy the binary of the application into the image
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [ python-app ];
          pathsToLink = [ "/" ];
        };
      };
      
    in
      {
        packages.${system} = rec {
          wlo-topic-assistant = python-app;
          docker = docker-img;
          env = poetry-env;
          default = wlo-topic-assistant;
        };
        devShells.${system}.default = pkgs.mkShell {
          buildInputs = [
            pkgs.poetry
            pkgs.nodePackages.pyright
            # poetry-env
          ];
        };
      };
}
