let
  nixpkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/057f9aecfb71c4437d2b27d3323df7f93c010b7e.tar.gz";
    sha256 = "1ndiv385w1qyb3b18vw13991fzb9wg4cl21wglk89grsfsnra41k";
  }) {};
in

nixpkgs.mkShell {
  buildInputs = [
    nixpkgs.python311
    nixpkgs.pipenv
    nixpkgs.bashInteractive
    nixpkgs.coreutils
    nixpkgs.git
    nixpkgs.gnutar
  ];

  # using a shellHook to install pipenv dependencies as nkpkgs don't have all the required packages for mike module
  shellHook = ''
    echo "Setting up pipenv environment..."
    export PIPENV_PIPFILE="build/Pipfile"
    # this will be skipped in gh-pages github branch as it doesn't have a Pipfile, it is managed by mike module with different content
    if [ -f "$PIPENV_PIPFILE" ]; then
      pipenv install --ignore-pipfile
    else
      echo "Pipfile not found, skipping pipenv install."
    fi
  '';
}
