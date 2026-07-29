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
# --disable-partial-static: link libstdc++ dynamically. --enable-partial-static
#   (default) passes -static-libstdc++ which strips DT_NEEDED libstdc++.so.6,
#   causing unresolved C++ allocator operators at runtime.
#   Manually preserve -static-libgcc and -Wl,-gc-sections (safe, no such issues).
CFLAGS="-march=x86-64-v3 -mtune=generic -O3"
CXXFLAGS="${CFLAGS}"
LDFLAGS="-Wl,--as-needed -Wl,-z,relro -Wl,-z,now -static-libgcc -Wl,-gc-sections"

./configure \
    --prefix=/usr \
    --enable-jemalloc \
    --enable-ccwarn \
    --disable-partial-static \
    CFLAGS="${CFLAGS}" \
    CXXFLAGS="${CXXFLAGS}" \
    LDFLAGS="${LDFLAGS}"

# ----- Build -----
make -j$(nproc)

# ----- Install to staging -----
rm -rf "${STAGING_DIR}"
make install DESTDIR="${STAGING_DIR}"

# Strip ELF binaries
find "${STAGING_DIR}" -type f -executable -print0 2>/dev/null | while IFS= read -r -d '' f; do
    file --brief "$f" | grep -qi 'elf' && strip "$f" || true
done

# ----- Build packages with fpm -----
mkdir -p "${DIST_DIR}"
gem install fpm -v '~> 1.15.0' --no-document 2>/dev/null || true

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
    --depends zlib \
    --depends lz4 \
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
    --depends zlib1g \
    --depends liblz4-1 \
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
