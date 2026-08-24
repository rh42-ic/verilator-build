#!/usr/bin/env bash
# Smoke test: compile and run the bundled fulladder design with the
# installed verilator, proving the package works end-to-end. Runs on old
# systems (g++ 8) too: the plain combinational fulladd module needs no
# --timing, unlike the testbench in adder_and_tb.sv which uses # delays
# (timing models require a C++20-coroutine compiler, GCC 10+).
set -euo pipefail

command -v verilator >/dev/null || {
    echo "ERROR: verilator not found in PATH" >&2
    exit 1
}

echo "=== verilator --version ==="
verilator --version

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

# Resolve the script dir BEFORE changing into WORKDIR: dirname "$0" is
# relative to the caller's current directory.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "${WORKDIR}"

cat >main.cpp <<'EOF'
#include "Vfulladd.h"
#include "verilated.h"
#include <cstdio>
int main(int argc, char** argv) {
    VerilatedContext ctx;
    ctx.commandArgs(argc, argv);
    Vfulladd top{&ctx};
    top.a = 3; top.b = 4; top.c_in = 0;
    top.eval();
    if (top.sum != 7 || top.c_out != 0) {
        std::printf("FAIL: 3+4 = %u (c_out=%u)\n", (unsigned)top.sum, (unsigned)top.c_out);
        return 1;
    }
    std::printf("SMOKE OK: 3+4 = %u (c_out=%u)\n", (unsigned)top.sum, (unsigned)top.c_out);
    return 0;
}
EOF

echo "=== verilating fulladd (--cc --exe --build --top-module fulladd) ==="
verilator --cc --exe --build --top-module fulladd \
    "${SCRIPT_DIR}/adder_and_tb.sv" --exe main.cpp -o sim

echo "=== running simulation ==="
./obj_dir/sim

echo "=== SMOKE TEST PASSED ==="
