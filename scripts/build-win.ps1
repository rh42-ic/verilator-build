# Build Verilator for Windows with MSVC and package it as a ZIP.
# Modeled on the upstream CI scripts ci/ci-win-compile.ps1 and ci/ci-win-test.ps1.
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
param(
    [Parameter(Mandatory = $true)]
    [string]$Tag
)

$ErrorActionPreference = "Stop"

$Version = $Tag.TrimStart('v')
$Root = Split-Path -Parent $PSScriptRoot
$Work = Join-Path $Root "win-work"
$SrcDir = Join-Path $Work "verilator-src"
$InstallDir = Join-Path $Work "install"
$DistDir = Join-Path $Root "dist"
$WinFlexBison = Join-Path $Work "win_flex_bison"
$NPROC = $env:NUMBER_OF_PROCESSORS

New-Item -ItemType Directory -Force -Path $Work, $DistDir | Out-Null

# ----- Enter the MSVC developer shell so cl/link are on PATH for Ninja -----
# (Same as upstream; also needed to compile winflexbison below.)
$VsPath = & "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe" `
    -latest -products * -property installationPath
if (-Not $VsPath) { throw "vswhere could not locate a Visual Studio installation" }
Import-Module "$VsPath/Common7/Tools/Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -VsInstallPath $VsPath -SkipAutomaticLocation -DevCmdArguments "-arch=x64 -host_arch=x64"

# ----- winflexbison (Windows flex/bison; upstream builds it from source) -----
if (-Not (Test-Path "$WinFlexBison/win_bison.exe")) {
    if (-Not (Test-Path (Join-Path $Work "winflexbison"))) {
        git clone --depth 1 https://github.com/lexxmark/winflexbison (Join-Path $Work "winflexbison")
    }
    Push-Location (Join-Path $Work "winflexbison")
    cmake -S . -B build --install-prefix $WinFlexBison
    cmake --build build --config Release -j $NPROC
    cmake --install build --prefix $WinFlexBison
    Pop-Location
}
$env:WIN_FLEX_BISON = $WinFlexBison

# ----- Clone Verilator at the tag -----
if (-Not (Test-Path $SrcDir)) {
    git clone --branch $Tag --depth 1 https://github.com/verilator/verilator.git $SrcDir
}

# ----- Configure, build and install -----
# Release flags: /O2 for performance, /arch:AVX2 to match the x86-64-v3 tier of
# the Linux packages. The verilator target already forces /MT (static CRT),
# /bigobj and /GL+/LTCG (INTERPROCEDURAL_OPTIMIZATION_RELEASE) on MSVC, so the
# resulting verilator_bin.exe has no VC++ runtime DLL dependency.
Push-Location $SrcDir
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release `
    --install-prefix $InstallDir `
    "-DCMAKE_CXX_FLAGS_RELEASE=/O2 /arch:AVX2 /DNDEBUG"
cmake --build build -j $NPROC
cmake --install build --prefix $InstallDir
Pop-Location

# ----- Test: build the official cmake_tracing_c example (upstream test) -----
Push-Location $InstallDir
$env:VERILATOR_ROOT = (Get-Location).Path
Push-Location examples/cmake_tracing_c
New-Item -ItemType Directory -Force -Path build | Out-Null
Push-Location build
cmake .. "-DCMAKE_CXX_FLAGS_RELEASE=/O2"
cmake --build . --config Release -j $NPROC
# Run the example (upstream left this disabled pending issue#5163; verify here
# with a timeout so a hang cannot stall the job).
$exe = Join-Path (Get-Location) "Release/example.exe"
if (-Not (Test-Path $exe)) { throw "example.exe was not built" }
$p = Start-Process -FilePath $exe -WorkingDirectory (Get-Location) -PassThru
if (-Not $p.WaitForExit(180000)) {
    Stop-Process -Id $p.Id -Force
    throw "example.exe timed out"
}
if ($p.ExitCode -ne 0) { throw "example.exe failed with exit code $($p.ExitCode)" }
Pop-Location; Pop-Location; Pop-Location

# ----- Smoke: verilator_bin --version -----
& (Join-Path $InstallDir "bin/verilator_bin.exe") --version
if ($LASTEXITCODE -ne 0) { throw "verilator_bin --version failed" }

# ----- Package as ZIP with a README -----
@'
Verilator {version} for Windows (MSVC build)
============================================

System requirements
  - Windows 10 1607 or later (static CRT /MT; UCRT is part of the OS)
  - CPU with AVX2 (Intel Haswell 2013+ / AMD Excavator 2015+)

Contents
  bin/       verilator_bin.exe (compiler engine) and perl wrapper scripts
  include/   Verilated runtime library (C++14; models compile with MSVC or g++)
  examples/  CMake examples (start with cmake_tracing_c)
  verilator-config.cmake   CMake package config

Runtime prerequisites (not bundled)
  - Strawberry Perl        https://strawberryperl.com   (runs bin/verilator)
  - A C++ compiler for the generated model: Microsoft Visual Studio 2022
    (recommended, use --compiler msvc) or MinGW-w64 g++
  - CMake 3.15+ for the CMake workflow
  - FST tracing additionally needs lz4 headers (e.g. via vcpkg)

Usage
  1. Extract the archive, e.g. to C:\verilator
  2. Set VERILATOR_ROOT=C:\verilator (the verilator wrapper scripts need it)
  3. Add C:\verilator\bin and your Perl\bin to PATH
  4. Verilate and build:
       verilator --cc --compiler msvc --binary your_design.v
     or use the CMake examples:
       cd examples\cmake_tracing_c && cmake -S . -B build && cmake --build build

Verified on build: verilator_bin --version, cmake_tracing_c example built and run.
Docs: https://verilator.org/guide/latest/
'@ -replace '\{version\}', $Version | Set-Content -Path (Join-Path $InstallDir "README.txt") -Encoding utf8

Push-Location $InstallDir
$zip = Join-Path $DistDir "verilator-${Version}-win64.zip"
Compress-Archive -Path (Get-ChildItem -Force) -DestinationPath $zip -CompressionLevel Optimal
Pop-Location

# ----- Verify the archive -----
Write-Host "=== Archive contents (top level) ==="
tar -tf $zip | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique
Get-Item $zip | ForEach-Object {
    Write-Host ("=== {0} ({1:N1} MB) ===" -f $_.Name, ($_.Length / 1MB))
}
if (-Not (Test-Path $zip)) { throw "ZIP was not created" }
