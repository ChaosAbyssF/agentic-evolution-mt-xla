# MUSA Platform Guide (Moore Threads)

MUSA 是摩尔线程的 GPU 编程平台，语法与 CUDA 高度兼容。

## Toolchain Overview

| Tool | Purpose | Usage |
|------|---------|-------|
| mcc | MUSA Compiler | Compile .mu/.cu files |
| msys | Profiling System | Capture and analyze profiles |
| musaInfo | Device Query | Get GPU information |
| mthreads-gmi | GPU Management | Monitor GPU status |
| musify-text | Code Migration | Convert CUDA to MUSA |
| mccl | Communication Library | Multi-GPU |

## Compiler (mcc)

    mcc -O3 kernel.mu -o kernel
    mcc -O3 -arch=mp_21 kernel.mu -o kernel   # MTT S80
    mcc -O3 -arch=mp_22 kernel.mu -o kernel   # MTT S300/S4000
    mcc -v

Known version: mcc 4.3.5, MUSA 4.3

## Current Project Environment

For this workflow, the user must provide:

- remote host/user
- target container
- remote workspace root
- actual SDK and dependency locations

Use remote MUSA measurements from the user-provided environment as the only
acceptance signal.

## Profiling (msys)

    msys profile ./my-application
    msys analyze result.msys-rep
    msys stats result.msys-rep

Commands: profile, launch, start, stop, analyze, stats, export

## Device Information

    musaInfo
    mthreads-gmi
    musa_version_query

## Libraries

mublas (cuBLAS), mublasLt (cuBLASLt), mudnn (cuDNN), mufft (cuFFT), musparse (cuSPARSE), murand (cuRAND), musolver (cuSOLVER)

For this project, prioritize:

- `mudnn`
- `mublas`
- existing runtime/backend paths
- XLA custom-call integration

## Code Migration

    musify-text input.cu > output.mu

## Architectures

- MTT S80: mp_21, 48GB GDDR6
- MTT S300/S4000: mp_22
