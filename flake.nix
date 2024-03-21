{
  description = "The WLO topic assistant, packaged in pure Nix";

  inputs = {
    # stable branch of the nix package repository
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # utilities
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    # automatic testing of the service
    openapi-checks = {
      url = "github:openeduhub/nix-openapi-checks";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    # external data that is versioned through the flake.lock
    nltk-data = {
      url = "github:nltk/nltk_data";
      flake = false;
    };
    oeh-metadata-vocabs = {
      url = "github:openeduhub/oeh-metadata-vocabs";
      flake = false;
    };
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
        # import the packages from nixpkgs
        pkgs = nixpkgs.legacyPackages.${system};
        # the python version we are using
        python = pkgs.python3;
        # utility to easily filter out unnecessary files from the source
        nix-filter = self.inputs.nix-filter.lib;

        ### create the python installation for the application
        python-packages-build = py-pkgs:
          with py-pkgs; [
            fastapi
            pydantic
            uvicorn
            rdflib
            nltk
            sentence-transformers
            scikit-learn
            pandas
            torch
            treelib
          ];

        ### create the python installation for development
        # the development installation contains all build packages,
        # plus some additional ones we do not need to include in production.
        python-packages-devel = py-pkgs:
          with py-pkgs; [
            ipython
            jupyter
            black
            isort
          ]
          ++ (python-packages-build py-pkgs);

        ### build the python application (i.e. the webservice)
        # unzip nltk-stopwords, an external dependency we are using
        nltk-stopwords = pkgs.runCommand "nltk-stopwords" { } ''
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
          version = "0.1.4";
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
          makeWrapperArgs = [ "--set NLTK_DATA $out/lib/nltk_data" ];
        };

        # build pre-loader; this creates the topic assistants at build time
        wlo-topic-assistant-preload =
          python.pkgs.buildPythonApplication
            (wlo-topic-assistant-spec // {
              pname = "wlo-topic-assistant-preload";
              # prevent unnecessary rebuilds
              src = nix-filter {
                root = self;
                include = [
                  ./src/wlo_topic_assistant/__init__.py
                  ./src/wlo_topic_assistant/_version.py
                  ./src/wlo_topic_assistant/generate_assistants.py
                  ./src/wlo_topic_assistant/topic_assistant.py
                  ./src/wlo_topic_assistant/topic_assistant2.py
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
                substituteInPlace src/wlo_topic_assistant/*.py \
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
            export TRANSFORMERS_CACHE=$TMPDIR
            mkdir $out
            ${wlo-topic-assistant-preload}/bin/preload $out
          '';
        };

        # build the web service
        wlo-topic-assistant =
          python.pkgs.buildPythonApplication
            (wlo-topic-assistant-spec // {
              pname = "wlo-topic-assistant";
              src = nix-filter {
                root = self;
                include = [
                  "src"
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
                substituteInPlace src/wlo_topic_assistant/webservice.py \
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
            Cmd = [ "${wlo-topic-assistant}/bin/wlo-topic-assistant" ];
          };
        };

      in
      rec {
        # the packages that we can build
        packages = {
          inherit wlo-topic-assistant;
          preload = wlo-topic-assistant-assistants;
          default = wlo-topic-assistant;
        } // (nixpkgs.lib.optionalAttrs
          # only build docker images on linux systems
          (system == "x86_64-linux" || system == "aarch64-linux")
          { docker = docker-img; });
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
        checks = { } // (nixpkgs.lib.optionalAttrs
          # only run the VM checks on linux systems
          (system == "x86_64-linux" || system == "aarch64-linux")
          {
            test-service =
              self.inputs.openapi-checks.lib.${system}.test-service {
                service-bin =
                  "${wlo-topic-assistant}/bin/${wlo-topic-assistant.pname}";
                service-port = 8080;
                openapi-domain = "/openapi.json";
                memory-size = 4096;
              };
          });
      });
}
