{ this, lib, ... }: {
  this.options.enable = lib.mkEnableOption "test foo bar";
  config = lib.mkIf (this.cfg.enable) {
    baz = 114514;
  };
}
