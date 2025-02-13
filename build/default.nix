let
  nixpkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/4e96537f163fad24ed9eb317798a79afc85b51b7.tar.gz";
    sha256 = "1hzn20sc1n2jwkim8ms300dp56f0hrpj3y2h477mlxykkk2cyp0q";
  }) {};
in

nixpkgs.mkShell {
  buildInputs = [
    nixpkgs.python312
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
