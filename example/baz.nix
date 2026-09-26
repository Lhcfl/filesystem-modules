{ lib, ... }: {
  options.baz = lib.mkOption {
    type = lib.types.int;
    default = 1;
  };
}
