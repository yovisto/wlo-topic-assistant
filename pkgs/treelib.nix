# automatically generated from the following command:
# nix-template python -u https://pypi.org/project/treelib/ --no-meta pkgs/treelib.nix
{ lib
, buildPythonPackage
, fetchPypi
, six
}:

buildPythonPackage rec {
  pname = "treelib";
  version = "1.6.4";
  format = "setuptools";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-Gi6Dj2uZ4mkLw9mS1aHwTNtK9lZL12iIg8I9FyV7uyo=";
  };

  propagatedBuildInputs = [
    six
  ];

  pythonImportsCheck = [ "treelib" ];

}
