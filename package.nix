{
  vimUtils,
  lib,
}:

vimUtils.buildVimPlugin rec {
  pname = "todoview-nvim";
  version = "0.1.0";

  src = builtins.path {
    name = "${pname}-${version}";
    path = lib.cleanSource ./.;
  };

  meta = {
    license = lib.licenses.mit;
  };
}
