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

  resolve =
    { path, file }:
    let
      sourceModule = builtins.trace { inherit path file; } import file;
      originalFunctionArgs = lib.functionArgs sourceModule;
      neededFunctionArgs = (removeAttrs originalFunctionArgs [ "this" ]) // {
        config = false;
      };
      withPath =
        data: if data == null then { } else lib.foldr (cur: acc: { ${cur} = acc; }) data (base ++ path);
    in
    lib.setFunctionArgs (
      args@{ config, ... }:
      let
        this = {
          inherit file path;
          cfg = builtins.foldl' (c: key: c.${key}) config (base ++ path);
        };

        result = sourceModule (args // { inherit this; });
        removed = removeAttrs result [ "this" ];
        defination = result.this or { };
        optionsAppended = lib.recursiveUpdate removed {
          options = withPath defination.options or null;
        };
        ret = optionsAppended;
      in
      ret
    ) neededFunctionArgs;
in
{
  imports = (map resolve applyFilter);
}
