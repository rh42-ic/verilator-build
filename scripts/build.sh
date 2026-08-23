#!/usr/bin/env bash
# Build Verilator from source for RHEL 8+ / x86-64-v3
set -euo pipefail

TAG="${1:?Usage: $0 <verilator-git-tag>}"
VERSION="${TAG#v}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGING_DIR="${SCRIPT_DIR}/../staging"
DIST_DIR="${SCRIPT_DIR}/../dist"
SRC_DIR="${SCRIPT_DIR}/../verilator-src"

# ----- Enable GCC 15 -----
source /opt/rh/gcc-toolset-15/enable

# ----- Clone Verilator -----
if [ ! -d "${SRC_DIR}" ]; then
    git clone --branch "${TAG}" \
        --depth 1 \
        https://github.com/verilator/verilator.git "${SRC_DIR}"
fi

cd "${SRC_DIR}"

# ----- Generate configure script -----
autoconf

# ----- Configure -----
# x86-64-v3: Haswell (2013+) — AVX2, FMA, BMI, BMI2, LZCNT
# Flags match the official CI (ci/ci-build.bash) where possible:
#   --enable-ccwarn        official CI default (ccwarn=true): warnings are errors
#   --enable-longtests     official build flag (affects test_regress only)
#   --enable-light-debug   official build flag; reduces the debug executables
#                          to backtrace-quality debug info (smaller packages)
# jemalloc is NOT passed explicitly: like the official CI, configure
# auto-detects it (default=check) from the jemalloc-devel package installed
# by install-deps.sh.
#
# Deviations kept for old-OS compatibility only:
#   --disable-partial-static  --enable-partial-static (the default) links
#     -static-libstdc++, embedding the GCC 15 libstdc++, which requires glibc
#     symbols newer than 2.28 and crashes on RHEL 8 / Debian 10.
#   -static-libgcc in LDFLAGS  configure only adds it under partial-static;
#     kept so the binary does not depend on the old system libgcc_s.so.1.
#   -march=x86-64-v3  documented product requirement (see README).
CFLAGS="-march=x86-64-v3 -mtune=generic -O3 -ffunction-sections -fdata-sections"
CXXFLAGS="${CFLAGS}"
LDFLAGS="-Wl,--as-needed -Wl,-z,relro -Wl,-z,now -static-libgcc -Wl,-gc-sections"

./configure \
    --prefix=/usr \
    --enable-ccwarn \
    --enable-longtests \
    --enable-light-debug \
    --disable-partial-static \
    CFLAGS="${CFLAGS}" \
    CXXFLAGS="${CXXFLAGS}" \
    LDFLAGS="${LDFLAGS}"

# ----- Build -----
# Same flow as the official CI (ci/ci-build.bash): ccache stats around the
# build, -k keeps going so every error is reported in one pass, and the
# eviction bounds the cache to (build time + 60s) of fresh entries.
ccache -z
BUILD_START=$SECONDS
make -j"$(nproc)" -k
ccache -svv
ccache --evict-older-than "$((SECONDS - BUILD_START + 60))s"
ccache -svv

# ----- Install to staging -----
rm -rf "${STAGING_DIR}"
make install DESTDIR="${STAGING_DIR}"

# Strip ELF binaries. Keep *_dbg binaries intact: they are the shipping
# debug builds (verilator_bin_dbg, verilator_coverage_bin_dbg) and stripping
# them destroys their only purpose.
find "${STAGING_DIR}" -type f -executable -print0 2>/dev/null | while IFS= read -r -d '' f; do
    case "$(basename "$f")" in
    *_dbg) continue ;;
    esac
    file --brief "$f" | grep -qi 'elf' && strip "$f" || true
done

# ----- Build packages with fpm -----
mkdir -p "${DIST_DIR}"
# fpm is installed by install-deps.sh; guard for manual runs
command -v fpm >/dev/null || {
    echo "ERROR: fpm not found (run scripts/install-deps.sh first)" >&2
    exit 1
}

# RPM (RHEL 8/9, AlmaLinux, Rocky Linux)
fpm -s dir -t rpm \
    -n verilator \
    -v "${VERSION}" \
    --iteration 1 \
    --architecture x86_64 \
    --description "Verilator — the fastest Verilog/SystemVerilog simulator. Compiles synthesizable SystemVerilog into cycle-accurate C++ or SystemC models." \
    --url "https://verilator.org" \
    --license "LGPL-3.0-only OR Artistic-2.0" \
    --maintainer verilator-build \
    --rpm-os linux \
    --depends perl \
    --depends python3 \
    --depends libstdc++ \
    --depends make \
    --depends gcc-c++ \
    --depends zlib-devel \
    --depends lz4-devel \
    --depends jemalloc \
    -p "${DIST_DIR}/verilator-${VERSION}-1.el8.x86_64.rpm" \
    -C "${STAGING_DIR}" usr/

# DEB (Ubuntu 18.04+, Debian 10+)
fpm -s dir -t deb \
    -n verilator \
    -v "${VERSION}" \
    --iteration 1 \
    --architecture amd64 \
    --description "Verilator — the fastest Verilog/SystemVerilog simulator. Compiles synthesizable SystemVerilog into cycle-accurate C++ or SystemC models." \
    --url "https://verilator.org" \
    --license "LGPL-3.0-only OR Artistic-2.0" \
    --maintainer verilator-build \
    --depends perl \
    --depends python3 \
    --depends libstdc++6 \
    --depends make \
    --depends g++ \
    --depends zlib1g-dev \
    --depends liblz4-dev \
    --depends libjemalloc2 \
    -p "${DIST_DIR}/verilator-${VERSION}-1_amd64.deb" \
    -C "${STAGING_DIR}" usr/

# ----- Print summary -----
echo ""
echo "===== Build complete: verilator ${VERSION} ====="
ls -lh "${DIST_DIR}/"
echo ""
echo "Binary requires:"
echo "  glibc ≥ 2.28 (RHEL 8+)"
echo "  CPU: x86-64-v3 (Haswell 2013+)"
echo ""
echo "Dynamic library dependencies of verilator_bin:"
ldd "${STAGING_DIR}/usr/bin/verilator_bin" 2>/dev/null | grep -v 'linux-vdso\|ld-linux\|libstdc++\|libgcc' || true
