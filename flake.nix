{
  description = "The WLO topic assistant, packaged in pure Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    nltk-data = {
      url = "github:nltk/nltk_data";
      flake = false;
    };
    oeh-metadata-vocabs = {
      url = "github:openeduhub/oeh-metadata-vocabs";
      flake = false;
    };
    openapi-checks = {
      url = "github:openeduhub/nix-openapi-checks";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    {
      # define an overlay to add wlo-topic-assistant to nixpkgs
      overlays.default = (final: prev: {
        inherit (self.packages.${final.system}) wlo-topic-assistant;
      });
    } //
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        projectDir = self;
        # import the packages from nixpkgs
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        # the python version we are using
        python = pkgs.python310;
        # utility to easily filter out unnecessary files from the source
        nix-filter = self.inputs.nix-filter.lib;
        
        ### create the python installation for the application
        python-packages-build = py-pkgs:
          with py-pkgs; [fastapi
                         pydantic
                         uvicorn
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
          with py-pkgs; [ipython
                         jupyter
                         black
                         isort
                        ]
          ++ (python-packages-build py-pkgs); 

        ### build the python application (i.e. the webservice)
        # unzip nltk-stopwords, an external dependency we are using
        nltk-stopwords = pkgs.runCommand "nltk-stopwords" {} ''
          mkdir $out
          ${pkgs.unzip}/bin/unzip ${self.inputs.nltk-data}/packages/corpora/stopwords.zip -d $out
        '';
        
        # download the sentence-transformer model being used
        # this cannot be moved to the flake inputs due to git LFS
        all-mpnet-base-v2 = pkgs.fetchgit {
          url = "https://huggingface.co/sentence-transformers/all-mpnet-base-v2";
          rev = "bd44305fd6a1b43c16baf96765e2ecb20bca8e1d";
          hash = "sha256-lsKdkbIeAUZIieIaCmp1FIAP4NAo4HW2W7+6AOmGO10=";
          fetchLFS = true;
        };

        # the oeh-metadata vocabulary
        oeh-metadata-vocabs = self.inputs.oeh-metadata-vocabs;

        # shared specification between pre-loader and web service
        wlo-topic-assistant-spec = {
          version = "0.1.2";
          propagatedBuildInputs = (python-packages-build python.pkgs);
          # no tests are available, nix built-in import check fails
          # due to how we handle import of nltk-stopwords
          doCheck = false;
          # put nltk-stopwords into a directory
          preBuild = ''
            mkdir -p $out/lib/nltk_data/corpora
            cp -r ${nltk-stopwords.out}/* $out/lib/nltk_data/corpora
          '';
          # make the created folder discoverable for NLTK
          makeWrapperArgs = ["--set NLTK_DATA $out/lib/nltk_data"];
        };

        # build pre-loader; this creates the topic assistants at build time
        wlo-topic-assistant-preload =
          python.pkgs.buildPythonApplication
            ( wlo-topic-assistant-spec // {
              pname = "wlo-topic-assistant-preload";
              # prevent unnecessary rebuilds
              src = nix-filter {
                root = self;
                include = [
                  ./wlo_topic_assistant/__init__.py
                  ./wlo_topic_assistant/_version.py
                  ./wlo_topic_assistant/generate_assistants.py
                  ./wlo_topic_assistant/topic_assistant.py
                  ./wlo_topic_assistant/topic_assistant2.py
                  ./setup.py
                  ./requirements.txt
                ];
                exclude = [
                  (nix-filter.matchExt "pyc")
                  (nix-filter.matchExt "ipynb")
                ];
              };
              # replace calls to resources from the internet with prefetched ones
              prePatch = ''
                substituteInPlace wlo_topic_assistant/*.py \
                  --replace \
                    "all-mpnet-base-v2" \
                    "${all-mpnet-base-v2}" \
                  --replace \
                    "https://raw.githubusercontent.com/openeduhub/oeh-metadata-vocabs/master/discipline.ttl" \
                    "${oeh-metadata-vocabs}/discipline.ttl" \
                  --replace \
                    "https://raw.githubusercontent.com/openeduhub/oeh-metadata-vocabs/master/oehTopics.ttl" \
                    "${oeh-metadata-vocabs}/oehTopics.ttl"
              '';
            });

        # run the pre-loader to create the topic assistants at build time
        wlo-topic-assistant-assistants = pkgs.stdenv.mkDerivation {
          pname = "wlo-topic-assistant-assistants";
          version = wlo-topic-assistant-preload.version;
          src = wlo-topic-assistant-preload.src;
          nativeBuildInputs = [
            pkgs.makeWrapper
            wlo-topic-assistant-preload
          ];
          installPhase = ''
            mkdir $out
            ${wlo-topic-assistant-preload}/bin/preload $out
          '';
        };

        # build the web service
        wlo-topic-assistant =
          python.pkgs.buildPythonApplication
            ( wlo-topic-assistant-spec // {
              pname = "wlo-topic-assistant";
              src = nix-filter {
                root = self;
                include = [
                  "wlo_topic_assistant"
                  ./setup.py
                  ./requirements.txt
                ];
                exclude = [
                  (nix-filter.matchExt "pyc")
                  (nix-filter.matchExt "ipynb")
                ];
              };
              # set the path of the topic assistants
              prePatch = ''
                substituteInPlace wlo_topic_assistant/webservice.py \
                  --replace \
                    "data/" \
                    "${wlo-topic-assistant-assistants}/"
              '';
            });

        ### build the docker image
        docker-img = pkgs.dockerTools.buildLayeredImage {
          name = wlo-topic-assistant.pname;
          tag = wlo-topic-assistant.version;
          config = {
            Cmd = ["${wlo-topic-assistant}/bin/wlo-topic-assistant"];
          };
        };

      in rec {
        # the packages that we can build
        packages = rec {
          inherit wlo-topic-assistant;
          preload = wlo-topic-assistant-assistants;
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
        checks = {
          openapi-check = self.inputs.openapi-checks.lib.${system}.openapi-valid {
            serviceBin = "${self.packages.${system}.wlo-topic-assistant}/bin/wlo-topic-assistant";
            openapiDomain = "openapi.json";
            memorySize = 4096;
          };
        };
      });
}
