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

安装包时会自动拉取：

| 库 | 用途 |
|----|------|
| libstdc++ | C++ 标准库 |
| zlib | FST 波形压缩 |
| lz4 | FST 波形压缩 |
| jemalloc | 高性能内存分配 |

## 已内置（静态链接，无需额外安装）

| 组件 | 说明 |
|------|------|
| libgcc | GCC 运行时（`-static-libgcc`） |

## 包含的文件

```
/usr/bin/
├── verilator              主入口（Perl）
├── verilator_bin          编译器引擎（优化版）
├── verilator_bin_dbg      调试版引擎
├── verilator_coverage_bin_dbg  覆盖率引擎
├── verilator_gantt        Gantt 图生成
├── verilator_profcfunc    函数性能分析
└── verilator_includer     多文件合并编译

/usr/share/verilator/
├── include/              运行时头文件（verilated.h 等）
├── examples/             示例项目
└── bin/                  内部工具脚本
```

## 增强工具（可选，自行安装）

| 工具 | 用途 | 安装方式 |
|------|------|---------|
| **z3** | SystemVerilog 约束随机化 | `dnf install z3` / `apt install z3` |
| **mold** | 加速 Verilated 模型链接 | [GitHub Release](https://github.com/rui314/mold/releases) |
| **ccache** | 加速 Verilated 模型重编译 | `dnf install ccache` / `apt install ccache` |
| **gtkwave** | 波形查看 | `dnf install gtkwave` / `apt install gtkwave` |

## 使用方法

```bash
verilator --binary --cc my_design.v      # 编译为可执行仿真模型
verilator --cc --trace my_design.v       # 带波形追踪
verilator --lint-only my_design.v        # 仅语法检查
```

详见 [Verilator 官方文档](https://verilator.org/guide/latest/)。

## 许可

LGPL-3.0-only OR Artistic-2.0 — 与 Verilator 上游一致。
