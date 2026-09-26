{ lib, ... }:
{
  directory,
  base ? [ ],
  filter ? ({ path, ... }: !(lib.any (lib.hasPrefix "_") path)),
  ...
}:
let
  listFiles =
    base: dir:
    let
      items = lib.attrsets.attrsToList (builtins.readDir dir);
      files = builtins.filter ({ name, value }: value == "regular" && lib.hasSuffix ".nix" name) items;
      dirs = builtins.filter ({ value, ... }: value == "directory") items;
    in
    [
      (map ({ name, ... }: {
        path = base ++ [ (lib.removeSuffix ".nix" name) ];
        file = dir + /${name};
      }) files)
      (map ({ name, ... }: listFiles (base ++ [ name ]) (dir + /${name})) dirs)
    ];

  allfiles = lib.flatten (listFiles [ ] directory);

  applyFilter = builtins.filter filter allfiles;

  normalize =
    mod:
    let
      checks = [
        "_class"
        "_file"
        "key"
        "disabledModules"
        "imports"
        "options"
        "config"
        "meta"
        "freeformType"
        "_class"
        "_file"
        "key"
        "disabledModules"
        "require"
        "imports"
        "freeformType"
      ];
    in
    if (lib.any (k: mod ? ${k}) checks) then mod else { config = mod; };

  resolve =
    { path, file }:
    let
      sourceModule = import file;
      sourceModuleFunction =
        if builtins.typeOf sourceModule == "lambda" then sourceModule else _: sourceModule;
      originalFunctionArgs = lib.functionArgs sourceModuleFunction;
      neededFunctionArgs = (removeAttrs originalFunctionArgs [ "this" ]) // {
        config = false;
      };
      withPath =
        data: if data == null then { } else lib.foldr (cur: acc: { ${cur} = acc; }) data (base ++ path);
    in
    lib.setDefaultModuleLocation file (
      lib.setFunctionArgs (
        args@{ config, ... }:
        let
          this = {
            inherit file path;
            config = builtins.foldl' (c: key: c.${key}) config (base ++ path);
            options = defination.options;
          };

          result = sourceModuleFunction (args // { inherit this; });
          removed = removeAttrs result [ "this" ];
          defination = result.this or { };
          optionsAppended = lib.recursiveUpdate (normalize removed) {
            options = withPath defination.options or null;
          };
          ret = optionsAppended;
        in
        ret
      ) neededFunctionArgs
    );
in
{
  imports = (map resolve applyFilter);
}
