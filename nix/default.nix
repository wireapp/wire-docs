let
  pkgs = import ./nixpkgs.nix;

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

  pythonOnNixEnv = pythonOnNix.python39Env {
    name = "python-on-nix-env";
    projects = {
      "myst-parser" = "0.15.2";
      # "sphinx" = "4.2.0";
      # "sphinx-autobuild" = "2021.3.14";
      # "sphinx-rtd-theme" = "0.5.2";
      # "recommonmark" = "0.7.1";
      #
      # missing:
      # "kroki" = "";
      # "rst2pdf" = "";
      # "multiversion" = "";
    };
  };
in
{
  inherit pkgs;

  env = pkgs.buildEnv {
    name = "dev-env";
    paths = [
      pkgs.awscli
      pkgs.jq
      pkgs.niv
      pkgs.zip
      pkgs.gnumake
      pkgs.entr
      pkgs.texlive.combined.scheme-full

      # (pkgs.python3.withPackages (ps: with ps; [ sphinx recommonmark rst2pdf sphinx-autobuild sphinxcontrib-fulltoc sphinxcontrib-kroki sphinx-multiversion sphinx_rtd_theme ])) # python-on-nix]))
    ]
    ++ [pythonOnNixEnv.out ];
  };
}

