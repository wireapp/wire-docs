{
  fetchPypi,
  buildPythonPackage,

  sphinx,
  pyyaml,
  # docutils,
  markdown-it-py,
  # mdit-py-plugins,
  typing-extensions
} :
buildPythonPackage rec {

  pname = "myst-parser";
  version = "0.17.0";
  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256:0q12jwj4xs2hsc9l68vgsibikmhc0ppzzxyp0fy7xdxcbix384nl";
  };

  propagatedBuildInputs = [
    sphinx
    pyyaml
    typing-extensions
  ];

}
