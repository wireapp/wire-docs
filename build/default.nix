let
  buildDir = builtins.getEnv "BUILD_DIR";
  nixpkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-24.11.tar.gz";
    sha256 = "0vq0jwz512xdbp86m5q93q4190ds5ibwmq28lapb6qa8k8ya0mbv";
  }) {};
in

nixpkgs.mkShell {
  buildInputs = [
    nixpkgs.python312
    nixpkgs.pipenv
    nixpkgs.bashInteractive
    nixpkgs.coreutils
    nixpkgs.git
  ];

  shellHook = ''
    echo "Setting up pipenv environment..."
    export PIPENV_PIPFILE="${buildDir}/Pipfile" 
    pipenv install --ignore-pipfile    
  '';
}