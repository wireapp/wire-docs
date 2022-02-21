{
  fetchPypi,
  buildPythonPackage,

  typing-extensions,
  attrs,
} :
buildPythonPackage rec {

  pname = "markdown-it-py";
  version = "2.0.1";
  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256:12p0sjz5b1fjwxnr8grnps7xdm9sizkbqf1rlc0dwb5bw4x1ap3v";
  };

  propagatedBuildInputs = [
    typing-extensions
    # mdurl
    attrs
  ];

}
