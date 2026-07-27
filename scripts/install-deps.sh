#!/usr/bin/env bash
# Install build dependencies for Verilator on AlmaLinux 8 / RHEL 8
set -euo pipefail

# ----- Enable required repos -----
dnf install -y epel-release dnf-plugins-core
dnf config-manager --set-enabled powertools

# ----- Build toolchain -----
# gcc-toolset-15: GCC 15 with C++23 and x86-64-v3 support.
# SCL-isolated under /opt/rh/ — does not affect glibc runtime dependency (stays 2.28).
dnf install -y \
    gcc-toolset-15-gcc \
    gcc-toolset-15-gcc-c++ \
    gcc-toolset-15-binutils \
    autoconf \
    bison \
    flex \
    git \
    make \
    perl \
    python38 \
    ccache \
    help2man \
    tar \
    xz \
    curl \
    file \
    cpio \
    findutils \
    gzip

# Enable GCC 15 for all subsequent commands in this shell
source /opt/rh/gcc-toolset-15/enable

# Ensure python3 points to Python 3.8+ (default 3.6 lacks walrus operator)
alternatives --set python3 /usr/bin/python3.8 2>/dev/null || ln -sf /usr/bin/python3.8 /usr/local/bin/python3

# ----- Build-time libraries -----
dnf install -y \
    zlib-devel \
    lz4-devel

# ----- Performance: jemalloc (--enable-jemalloc) -----
dnf install -y \
    jemalloc-devel \
    numactl-libs

# ----- Optional: SystemC support (for --sc output) -----
dnf install -y systemc-devel 2>/dev/null || echo "systemc-devel not available, --sc disabled"

# ----- Optional: SMT solver (detected at build, used at runtime) -----
dnf install -y z3 2>/dev/null || echo "z3 not available, constraint randomization disabled"

# ----- mold linker (build-time and runtime acceleration) -----
MOLD_VERSION=2.38.0
if ! mold --version 2>/dev/null | grep -q "${MOLD_VERSION}"; then
    curl -fsSL "https://github.com/rui314/mold/releases/download/v${MOLD_VERSION}/mold-${MOLD_VERSION}-x86_64-linux.tar.gz" |
        tar xz -C /usr/local --strip-components=1
fi

# ----- Packaging tools -----
dnf install -y \
    rpm-build \
    dpkg-dev \
    ruby \
    rubygems

# fpm: v1.15 is the last version supporting Ruby 2.5 (AlmaLinux 8 default)
gem install fpm -v '~> 1.15.0' --no-document

echo '=== Build environment ready ==='
gcc --version | head -1
g++ --version | head -1
flex --version | head -1
bison --version | head -1
python3 --version
