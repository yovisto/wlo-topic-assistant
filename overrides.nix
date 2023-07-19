# fix missing dependencies of python packages
{self, super, python, lib}:
(lib.listToAttrs (
  # packages that are missig setuptools
  lib.lists.forEach
    ["autocommand" "justext" "courlan" "htmldate" "trafilatura" "confection" "treelib"]
    (x: {
      name = x;
      value = super."${x}".overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [self.setuptools];
      });
    })
  ++
  # packages that are missing hatchling
  lib.lists.forEach
    ["annotated-types"]
    (x: {
      name = x;
      value = super."${x}".overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [self.hatchling];
      });
    })
  ++
  # packages that should not be compiled manually
  lib.lists.forEach
    [ "pydantic" "pydantic-core" "scikit-learn" "pandas" "spacy" "spacy-transformers" "spacy-alignments" "safetensors" "tokenizers" "torch" ]
    (x: {
      name = x;
      value = super."${x}".override {
        preferWheel = true;
      };
    })
))
