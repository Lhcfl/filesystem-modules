# filesystem-modules

Turn a directory tree of `.nix` files into a single NixOS-style module, recursively.
Each file becomes a module whose options live at a path derived from its location in
the directory — `foo/bar.nix` declares options under `foo.bar`, `a.nix` under `a`, and
so on.

递归地把一个 `.nix` 文件目录树变成一个 NixOS 风格的 module。每个文件都会变成一个 module，
其 option 所在的路径由它在目录中的位置决定 —— `foo/bar.nix` 在 `foo.bar` 下声明 option，
`a.nix` 在 `a` 下，以此类推。

## Usage / 用法

Add the flake as an input and call `mkModule`:

把该 flake 作为 input 引入，然后调用 `mkModule`：

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
      base = [ "auto" "path" ]; # optional / 可选
    };
  in
  (nixpkgs-lib.lib.evalModules { modules = [ module ]; }).config
}
```

## How a directory maps to options / 目录如何映射为 option

Given this tree:

给定如下目录树：

```
example/
├── a.nix          -> path [ "a" ]
├── baz.nix        -> path [ "baz" ]
├── foo.nix        -> path [ "foo" ]
├── _internal.nix  -> skipped by the default filter / 被默认 filter 跳过
└── foo/
    └── bar.nix    -> path [ "foo" "bar" ]
```

Every regular file ending in `.nix` is imported as a module. The `.nix` suffix is
stripped and each directory level becomes one attribute. A file and a directory with
the same name address the same node: `foo.nix` handles the `foo` node itself, while
`foo/bar.nix` handles its `foo.bar` child.

每个以 `.nix` 结尾的普通文件都会被当作 module 引入。`.nix` 后缀被去掉，每一层目录成为一个属性。
同名的文件与目录指向同一个节点：`foo.nix` 处理 `foo` 节点本身，而 `foo/bar.nix` 处理它的子节点
`foo.bar`。

## The module interface / module 接口

Each `.nix` file must evaluate to a module function. Alongside the usual module
arguments (`lib`, `config`, `options`, ...), `mkModule` injects a `this` argument
describing where the module sits:

每个 `.nix` 文件都必须求值为一个 module 函数。除了常见的 module 参数（`lib`、`config`、
`options` 等）之外，`mkModule` 还会注入一个 `this` 参数，用来描述该 module 所处的位置：

| `this.` | meaning / 含义 |
| --- | --- |
| `this.file` | absolute path of the `.nix` file / 该 `.nix` 文件的绝对路径 |
| `this.path` | path components relative to `directory` (e.g. `[ "foo" "bar" ]`) / 相对于 `directory` 的路径分量（如 `[ "foo" "bar" ]`） |
| `this.cfg` | the evaluated config at `base ++ path` (the module's own subtree) / 在 `base ++ path` 处求值得到的 config（即该 module 自己的子树） |

A module declares options **relative to its own path** by returning them under a
`this` attribute:

module 通过把 option 放在返回集合的 `this` 属性下，来声明**相对于自身路径**的 option：

```nix
# example/foo/bar.nix
{ this, lib, ... }: {
  this.options.enable = lib.mkEnableOption "test foo bar";

  config = lib.mkIf this.cfg.enable {
    baz = 114514;
  };
}
```

This declares `foo.bar.enable` (see [the `base` argument](#arguments)), and its
`config` overrides the top-level `baz` option once it is enabled.

这里声明了 `foo.bar.enable`（参见 [`base` 参数](#arguments)），当它被启用时，它的 `config`
会覆盖顶层的 `baz` option。

Options declared at the **top level** of the returned set are absolute — they are not
relativized:

在返回集合**顶层**声明的 option 是绝对的 —— 不会被相对化：

```nix
# example/baz.nix
{ lib, ... }: {
  options.baz = lib.mkOption { type = lib.types.int; default = 1; };
}
```

So a module can mix both: `this.options.*` for namespaced, path-local options and plain
`options.*` / `config.*` for options shared across the whole evaluation.

因此一个 module 可以两者混用：`this.options.*` 用于带命名空间、绑定到自身路径的 option，
而普通的 `options.*` / `config.*` 用于整个求值过程共享的 option。

For the example tree above, `evalModules { modules = [ module ]; }` yields:

对于上文的示例目录树，`evalModules { modules = [ module ]; }` 的结果是：

```nix
{
  a = 1;                             # example/a.nix
  baz = 1;                           # example/baz.nix (overridden by foo/bar.nix)
  boo = 1;                           # example/foo.nix
  foo.bar.enable = false;            # example/foo/bar.nix
}
```

## Arguments / 参数

```nix
mkModule {
  directory,   # path: the directory to convert / 要转换的目录
  base ? [],   # list of strings: prefix for `this.options` / `this.cfg` / 字符串列表：`this.options` 与 `this.cfg` 的前缀
  filter ? ({ path, ... }: !(lib.any (lib.hasPrefix "_") path)),
  ...
}
```

- **`directory`** — required; the tree to walk recursively. Only regular `.nix` files
  are picked up.

  **`directory`** —— 必填；要递归遍历的目录树。只有普通的 `.nix` 文件会被收集。

- **`base`** — prepended to every module's path when resolving `this.options` and
  `this.cfg`. With `base = [ "auto" "path" ]`, `foo/bar.nix` declares
  `auto.path.foo.bar.*`, and `this.cfg` is read from `config.auto.path.foo.bar`.

  **`base`** —— 在解析 `this.options` 与 `this.cfg` 时，前置到每个 module 的路径上。当
  `base = [ "auto" "path" ]` 时，`foo/bar.nix` 声明的是 `auto.path.foo.bar.*`，
  而 `this.cfg` 读取自 `config.auto.path.foo.bar`。

- **`filter`** — receives each `{ path, file }` and keeps it when it returns true.
  `path` is the list of components (already stripped of `.nix`), `file` is the file
  path. The default ignores anything under a component starting with `_`, which is the
  convention for non-module helper files such as `_internal.nix`.

  **`filter`** —— 接收每个 `{ path, file }`，返回 true 时保留。`path` 是路径分量列表
  （已去掉 `.nix`），`file` 是文件路径。默认会忽略任何路径分量以 `_` 开头的内容，这是
  `_internal.nix` 这类非 module 辅助文件的约定。


