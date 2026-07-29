# verilator-build

预编译的 [Verilator](https://github.com/verilator/verilator) RPM/DEB 包。

## 下载

从 [Releases](https://github.com/rh42-ic/verilator-build/releases) 页面获取：

| 文件 | 适用系统 |
|------|---------|
| `verilator-{version}-1.el8.x86_64.rpm` | RHEL 8/9、AlmaLinux、Rocky Linux |
| `verilator-{version}-1_amd64.deb` | Ubuntu 18.04+、Debian 10+ |

## 系统要求

| 要求 | 最低版本 |
|------|---------|
| **glibc** | ≥ 2.28 |
| **CPU** | x86-64-v3（Intel Haswell 2013+ / AMD Excavator 2015+） |

## 安装

**RHEL / AlmaLinux / Rocky Linux：**

```bash
dnf install ./verilator-{version}-1.el8.x86_64.rpm
```

**Ubuntu / Debian：**

```bash
apt install ./verilator-{version}-1_amd64.deb
```

## 运行时依赖

| 包 | 用途 |
|----|------|
| perl, python3 | 脚本解释器 |
| make, gcc-c++ (或 g++) | 编译生成的 C++ 模型 |
| libstdc++ | C++ 标准库 |
| zlib-devel, lz4-devel | FST 波形压缩 |
| jemalloc | 高性能内存分配 |

## 内置

| 组件 |
|------|
| libgcc |

## 包含的文件

```
/usr/bin/
├── verilator
├── verilator_bin
├── verilator_bin_dbg
├── verilator_coverage_bin_dbg
├── verilator_gantt
├── verilator_profcfunc
└── verilator_includer

/usr/share/verilator/
├── include/
├── examples/
└── bin/
```

## 可选工具

| 工具 | 用途 | 安装 |
|------|------|------|
| z3 | SystemVerilog 约束随机化 | `dnf install z3` / `apt install z3` |
| mold | 链接器 | [GitHub Release](https://github.com/rui314/mold/releases) |
| ccache | 编译缓存 | `dnf install ccache` / `apt install ccache` |
| gtkwave | 波形查看 | `dnf install gtkwave` / `apt install gtkwave` |

## 使用方法

```bash
verilator --binary --cc my_design.v
verilator --cc --trace my_design.v
verilator --lint-only my_design.v
```

[Verilator 官方文档](https://verilator.org/guide/latest/)

## 许可

LGPL-3.0-only OR Artistic-2.0
