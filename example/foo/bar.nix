{ this, lib, ... }: {
  this.options.enable = lib.mkEnableOption "test foo bar";
  config = lib.mkIf (this.config.enable) {
    baz = builtins.trace this.options 114514;
  };
}
