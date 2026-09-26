{ lib, ... }: {
  options.a = lib.mkOption { type = lib.types.int; };
  config.a = 1;
}
