# CUDA Platform Guide (NVIDIA)

## Toolchain Overview

| Tool | Purpose |
|------|---------|
| nvcc | CUDA Compiler |
| nsys | Nsight Systems (system-level profiling) |
| ncu | Nsight Compute (kernel-level profiling) |
| nvidia-smi | GPU management |
| cuobjdump | Binary analysis |

## Compiler (nvcc)

    nvcc -O3 kernel.cu -o kernel
    nvcc -O3 -arch=sm_80 kernel.cu -o kernel  # A100
    nvcc -O3 -arch=sm_89 kernel.cu -o kernel  # RTX 4090
    nvcc -O3 -arch=sm_90 kernel.cu -o kernel  # H100

## Profiling

    nsys profile ./my-application
    ncu --set full ./my-application
    ncu -k my_kernel ./my-application

## Device Information

    nvidia-smi
    nvidia-smi -q

## Architectures

| GPU | Compute Cap | Notes |
|-----|-------------|-------|
| H100 | sm_90 | Hopper |
| A100 | sm_80 | Ampere |
| B200 | sm_100 | Blackwell |

## Libraries

cuBLAS, cuDNN, cuFFT, cuSPARSE, cuRAND, cuSOLVER, NCCL, CUTLASS
