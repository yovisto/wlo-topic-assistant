{
  description = "The WLO topic assistant, packaged in pure Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    {
      # define an overlay to add wlo-topic-assistant to nixpkgs
      overlays.default = (final: prev: {
        inherit (self.packages.${final.system}) wlo-topic-assistant;
      });
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        projectDir = self;
        # import the packages from nixpkgs
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        # the python version we are using
        python = pkgs.python310;

        ### create the python installation for the application
        python-packages-build = py-pkgs:
          with py-pkgs; [cherrypy
                         rdflib
                         nltk
                         sentence-transformers
                         scikit-learn
                         pandas
                         torchWithoutCuda
                         # dependencies from PyPi, generated through nix-template
                         (pkgs.callPackage
                           ./pkgs/treelib.nix
                           {inherit buildPythonPackage six;})
                        ];

        ### create the python installation for development
        # the development installation contains all build packages,
        # plus some additional ones we do not need to include in production.
        python-packages-devel = py-pkgs:
          with py-pkgs; [ipython jupyter black]
                        ++ (python-packages-build py-pkgs); 

        ### build the python application (i.e. the webservice)
        # fetch & unzip nltk-stopwords, an external dependency we are using
        nltk-stopwords = pkgs.fetchzip {
          url = "https://github.com/nltk/nltk_data/raw/5db857e6f7df11eabb5e5665836db9ec8df07e28/packages/corpora/stopwords.zip";
          hash = "sha256-tX1CMxSvFjr0nnLxbbycaX/IBnzHFxljMZceX5zElPY=";
        };
        
        # download the sentence-transformer model being used
        all-mpnet-base-v2 = pkgs.fetchgit {
          url = "https://huggingface.co/sentence-transformers/all-mpnet-base-v2";
          rev = "bd44305fd6a1b43c16baf96765e2ecb20bca8e1d";
          hash = "sha256-lsKdkbIeAUZIieIaCmp1FIAP4NAo4HW2W7+6AOmGO10=";
          fetchLFS = true;
        };

        # build the application itself
        wlo-topic-assistant = python.pkgs.buildPythonApplication {
          pname = "wlo-topic-assistant";
          version = "0.1.1";
          src = projectDir;
          propagatedBuildInputs = (python-packages-build python.pkgs);
          # no tests are available, nix built-in import check fails
          # due to how we handle import of nltk-stopwords
          doCheck = false;
          # put nltk-stopwords into a directory
          preBuild = ''
            mkdir -p $out/lib/nltk_data/corpora/stopwords
            cp -r ${nltk-stopwords.out}/* $out/lib/nltk_data/corpora/stopwords
          '';
          # make the created folder discoverable for NLTK
          makeWrapperArgs = ["--set NLTK_DATA $out/lib/nltk_data"];
          # replace calls to resources from the internet with prefetched ones
          postPatch = ''
            substituteInPlace wlo_topic_assistant/topic_assistant2.py --replace \
              "all-mpnet-base-v2" "${all-mpnet-base-v2}"
          '';
        };

        ### build the docker image
        docker-img = pkgs.dockerTools.buildImage {
          name = wlo-topic-assistant.pname;
          tag = wlo-topic-assistant.version;
          config = {
            Cmd = ["${wlo-topic-assistant}/bin/wlo-topic-assistant"];
            # because the wlo-topic-assistant tries accessing the internet,
            # we need to link to an ssl certificates file in the image.
            # in the future, we could modify the source code to try
            # reading local files instead, and then grab these in nix,
            # similarly to nltk-stopwords 
            Env = [ "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
          };
        };

      in rec {
        # the packages that we can build
        packages = rec {
          inherit wlo-topic-assistant;
          docker = docker-img;
          default = wlo-topic-assistant;
        };
        # the development environment
        devShells.default = pkgs.mkShell {
          buildInputs = [
            # the development installation of python
            (python-packages-devel python.pkgs)
            # non-python packages
            pkgs.nodePackages.pyright
            # for automatically generating nix expressions, e.g. from PyPi
            pkgs.nix-init
            pkgs.nix-template
          ];
        };
      });
}
