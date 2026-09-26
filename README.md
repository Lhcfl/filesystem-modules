# filesystem-modules

Recursively turn a directory tree of `.nix` files into a single NixOS-style module.
Each file becomes a module whose path is derived from its location: `foo/bar.nix` maps
to `foo.bar`, `a.nix` to `a`.

递归地把一个 `.nix` 文件目录树变成一个 NixOS 风格的 module。每个文件变成一个 module，
其路径由它在目录中的位置决定：`foo/bar.nix` 对应 `foo.bar`，`a.nix` 对应 `a`。

## Usage / 用法

```nix
{
  inputs = {
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
    filesystem-modules.url = "github:you/filesystem-modules";
    filesystem-modules.nixpkgs-lib.follows = "nixpkgs-lib";
  };

  outputs = { nixpkgs-lib, filesystem-modules, ... }:
  let
    module = filesystem-modules.mkModule {
      directory = ./example;
      base = [ "auto" "path" ];
    };
  in
  (nixpkgs-lib.lib.evalModules { modules = [ module ]; }).config;
}
```

## Arguments / 参数

```nix
mkModule {
  directory,   # path: the directory to convert / 要转换的目录
  base ? [],   # list of strings: prefix for the path-relative `this` declarations and `this.config` / 字符串列表：相对于路径的 `this` 声明与 `this.config` 的前缀
  filter ? ({ path, ... }: !(lib.any (lib.hasPrefix "_") path)),
  ...
}
```

- **`directory`** — the tree to walk recursively. Files ending in `.nix` are imported;
  the suffix is stripped and each directory level becomes one attribute.

  **`directory`** —— 要递归遍历的目录树。以 `.nix` 结尾的文件会被引入；去掉后缀，每层目录
  成为一个属性。

- **`base`** — prepended to every module's path when placing the declarations made under
  its `this` attribute and when reading `this.config`.

  **`base`** —— 在放置 module 中位于其 `this` 属性下的声明、以及读取 `this.config` 时，
  前置到每个 module 的路径上。

- **`filter`** — receives each `{ path, file }` and keeps it when it returns true.
  `path` is the list of components (already stripped of `.nix`), `file` is the file path.
  The default ignores any component starting with `_`.

  **`filter`** —— 接收每个 `{ path, file }`，返回 true 时保留。`path` 是路径分量列表
  （已去掉 `.nix`），`file` 是文件路径。默认忽略任何以 `_` 开头的分量。

## The injected `this` / 注入的 `this`

Alongside the usual module arguments (`lib`, `config`, `options`, ...), every module is
given a `this` describing where it sits:

除了常见的 module 参数（`lib`、`config`、`options` 等），每个 module 还会拿到一个 `this`，
用来描述它所处的位置：

| `this.` | meaning / 含义 |
| --- | --- |
| `this.file` | absolute path of the `.nix` file / 该 `.nix` 文件的绝对路径 |
| `this.path` | path components relative to `directory`, e.g. `[ "foo" "bar" ]` / 相对于 `directory` 的路径分量，如 `[ "foo" "bar" ]` |
| `this.config` | the config at `base ++ path` (the module's own subtree) / `base ++ path` 处的 config（该 module 自己的子树） |
| `this.options` | the options this module declared under its `this` attribute / 该 module 在其 `this` 属性下声明的 option |

Declarations made under `this.options` land at `base ++ path`:

在 `this.options` 下做的声明会落在 `base ++ path`：

```nix
# example/foo/bar.nix
{ this, lib, ... }: {
  this.options.enable = lib.mkEnableOption "test foo bar";

  config = lib.mkIf this.config.enable {
    baz = 114514;
  };
}
```

This file declares `foo.bar.enable` and, once enabled, overrides the top-level `baz`.

该文件声明 `foo.bar.enable`，一旦启用，就覆盖顶层的 `baz`。

## Example / 示例

```
example/
├── a.nix          -> [ "a" ]
├── baz.nix        -> [ "baz" ]
├── foo.nix        -> [ "foo" ]
├── _internal.nix  -> skipped by the default filter / 被默认 filter 跳过
└── foo/
    ├── bar.nix    -> [ "foo" "bar" ]
    └── lalala.nix -> [ "foo" "lalala" ]
```

`evalModules { modules = [ module ]; }` on the tree above yields:

对上文的目录树执行 `evalModules { modules = [ module ]; }` 得到：

```nix
{
  a = 1;                             # example/a.nix
  baz = 114514;                      # example/baz.nix, overridden by foo/bar.nix
  boo = 1;                           # example/foo.nix
  foo.bar.enable = true;             # example/foo/bar.nix, enabled by foo/lalala.nix
}
```
