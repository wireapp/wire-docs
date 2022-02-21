{
  fetchPypi,
  buildPythonPackage,

  flit
} :
buildPythonPackage rec {

  pname = "mdurl";
  format = "pyproject";
  version = "0.1.0";
  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256:145rx4wp50gmkab7iq9vkx9fz7rlw1yss6xj1y44ivh8j2b3m1wl";
  };

  nativeBuildInputs = [ flit ];

  propagatedBuildInputs = [
  ];

  doCheck = false;

}
