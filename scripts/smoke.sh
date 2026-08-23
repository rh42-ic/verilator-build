#!/usr/bin/env bash
# Smoke test: verilate a minimal design with tracing, compile it and run it.
# Verifies the installed verilator can produce a working simulator end-to-end.
# Uses only the binary and runtime files shipped in the package; no source tree.
set -euo pipefail

command -v verilator >/dev/null || { echo "ERROR: verilator not found in PATH" >&2; exit 1; }

echo "=== verilator --version ==="
verilator --version

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT
cd "${WORKDIR}"

cat > hello.v <<'EOF'
module hello(input logic clk);
    logic [31:0] count;
    always_ff @(posedge clk) begin
        count <= count + 1;
        if (count == 100) begin
            $display("Hello from Verilator: count=%0d", count);
            $finish;
        end
    end
    initial count = 0;
endmodule
EOF

cat > main.cpp <<'EOF'
#include "Vhello.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
int main(int argc, char** argv) {
    VerilatedContext ctx;
    ctx.commandArgs(argc, argv);
    ctx.traceEverOn(true);
    Vhello top{&ctx};
    VerilatedVcdC tfp;
    top.trace(&tfp, 99);
    tfp.open("hello.vcd");
    for (int i = 0; i < 200 && !ctx.gotFinish(); ++i) {
        top.clk = !top.clk;
        top.eval();
        ctx.timeInc(1);
    }
    tfp.close();
    if (!ctx.gotFinish()) {
        std::cerr << "FAIL: simulation did not finish in 200 cycles" << std::endl;
        return 1;
    }
    return 0;
}
EOF

echo "=== verilating hello.v (--binary --trace) ==="
verilator --binary --cc hello.v --exe main.cpp --trace -o sim

echo "=== building model ==="
make -C obj_dir -f Vhello.mk -j"$(nproc 2>/dev/null || echo 2)"

echo "=== running simulation ==="
OUTPUT="$(./obj_dir/sim)"
echo "${OUTPUT}"
echo "${OUTPUT}" | grep -q "Hello from Verilator: count=100" \
    || { echo "FAIL: unexpected simulation output" >&2; exit 1; }

[ -s hello.vcd ] || { echo "FAIL: no trace output produced" >&2; exit 1; }

echo "=== SMOKE TEST PASSED ==="
