{
  description = "The WLO topic assistant, packaged in pure Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      projectDir = self;
      # import the packages from nixpkgs
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      # the python version we are using
      python = pkgs.python310;

      ### build python packages not packaged in nixpkgs
      treelib = with python.pkgs; buildPythonPackage rec {
        pname = "treelib";
        version = "1.6.4";
        src = fetchPypi {
          inherit pname version;
          sha256 = "1a2e838f6b99e2690bc3d992d5a1f04cdb4af6564bd7688883c23d17257bbb2a";
        };
        # dependencies for this python package
        propagatedBuildInputs = [six];
      };

      ### create the python installation for the application
      python-packages-build = py-pkgs:
        with py-pkgs; [cherrypy
                       rdflib
                       treelib
                       nltk
                       sentence-transformers
                       scikit-learn
                       pandas
                       torchWithoutCuda
                      ];
      python-build = python.withPackages python-packages-build;

      ### create the python installation for development
      # the development installation contains all build packages,
      # plus some additional ones we do not need to include in production.
      python-packages-devel = py-pkgs:
        with py-pkgs; [ipython jupyter black] # some example packages
                      ++ (python-packages-build py-pkgs); 
      python-devel = python.withPackages python-packages-devel;
      
      ### build the python application (i.e. the webservice)
      # fetch & unzip nltk-stopwords, an external dependency we are using
      nltk-stopwords = pkgs.fetchzip {
        url = "https://github.com/nltk/nltk_data/raw/5db857e6f7df11eabb5e5665836db9ec8df07e28/packages/corpora/stopwords.zip";
        sha256 = "sha256-tX1CMxSvFjr0nnLxbbycaX/IBnzHFxljMZceX5zElPY=";
      };

      # build the application itself
      wlo-topic-assistant = python-build.pkgs.buildPythonApplication {
        pname = "wlo-topic-assistant";
        version = "0.1.1";
        src = projectDir;
        propagatedBuildInputs = [python-build];
        doCheck = false;
        # put nltk-punkt into a directory that nltk searches in
        preBuild = ''
          ${pkgs.coreutils}/bin/mkdir -p $out/nltk_data/corpora/stopwords &&
          ${pkgs.coreutils}/bin/cp -r ${nltk-stopwords.out}/* $out/nltk_data/corpora/stopwords
        '';
      };

      ### build the docker image
      docker-img = pkgs.dockerTools.buildImage {
        name = wlo-topic-assistant.pname;
        tag = wlo-topic-assistant.version;
        config = {
          WorkingDir = "/";
          Cmd = ["/bin/wlo-topic-assistant"];
          # because the wlo-topic-assistant tries accessing the internet,
          # we need to link to an ssl certificates file in the image.
          # in the future, we could modify the source code to try
          # reading local files instead, and then grab these in nix,
          # similarly to nltk-stopwords 
          Env = [ "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
        };
        # copy the binaries and nltk_data of the application into the image
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [ wlo-topic-assistant ];
          pathsToLink = [ "/bin" "/nltk_data" ];
        };
      };
      
    in
      rec {
        # the packages that we can build
        packages.${system} = rec {
          inherit wlo-topic-assistant;
          docker = docker-img;
          default = docker;
        };
        # the development environment
        devShells.${system}.default = pkgs.mkShell {
          buildInputs = [
            # the development installation of python
            python-devel
            # non-python packages
            pkgs.poetry
            pkgs.nodePackages.pyright
          ];
        };
      };
}
