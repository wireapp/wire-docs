self: super: rec {
  python3 = super.python3.override ({
    packageOverrides = pself: psuper: {
      arabic-reshaper = pself.callPackage ./python/arabic-reshaper.nix {} ;
      rst2pdf = pself.callPackage ./python/rst2pdf.nix {};
      python-bidi = pself.callPackage ./python/python-bidi.nix {};
      svg2rlg = pself.callPackage ./python/svg2rlg.nix {};
      svglib = pself.callPackage ./python/svglib.nix {};
      sphinx-multiversion = pself.callPackage ./python/sphinx-multiversion.nix {};
      sphinxcontrib-kroki = pself.callPackage ./python/sphinxcontrib-kroki.nix {};
      mdurl = pself.callPackage ./python/mdurl.nix {};
      # markdown-it-py = pself.callPackage ./python/markdown-it-py.nix {};
      # myst-parser = pself.callPackage ./python/myst-parser.nix {};
    };
  });

  python3Packages = python3.pkgs;
}
