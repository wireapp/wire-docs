let
  pkgs = import ../nixpkgs.nix;

  # Import Python on Nix
  pythonOnNix = import
    (builtins.fetchGit {
      # Use `main` branch or a commit from this list:
      # https://github.com/on-nix/python/commits/main
      # We recommend using a commit for maximum reproducibility
      ref = "main";
      url = "https://github.com/on-nix/python";
    })
    {
      # Make Python on Nix use the same version of `nixpkgs`
      # for maximum compatibility
      inherit pkgs;
    };

  env = pythonOnNix.python39Env {
    name = "python-on-nix-env";
    projects = {
      "myst-parser" = "0.15.2";
    };
  };

in

env.out
