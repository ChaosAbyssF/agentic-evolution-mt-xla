# Kernel Optimization Patterns

## Whole-Model First

When the target is TensorFlow 2.15 whole-model inference, operator optimization
must follow this order:

1. Prove the operator is a real whole-model hotspot
2. Improve the local implementation
3. Integrate it through XLA custom call
4. Re-run the whole model

Local kernel gains that do not survive the XLA custom-call path do not count as
success.

## Level 1: Memory Access

- Coalesced memory access
- Shared memory tiling
- Register blocking
- Memory hierarchy optimization

## Level 2: Parallelism

- Warp-level primitives (shuffle, reduce, vote)
- Block-level cooperation
- Warp specialization
- Pipeline overlap . double buffering

## Level 3: Instruction Level

- Branch divergence elimination
- Memory fence selection
- Instruction scheduling and ILP

## Level 4: Tensor Core

- WMMA . tensor core intrinsics
- Matrix tiling strategy
- Overlap tensor ops with other work

## Level 5: Resource Allocation

- Register allocation vs occupancy
- Shared memory bank conflict avoidance
- Occupancy optimization

## Discovery Order

1. Correctness first
2. Whole-model hotspot ranking
3. XLA integration feasibility
4. Memory coalescing
5. Shared memory tiling
6. Warp-level optimization
7. Tensor core utilization
8. Micro-architecture tuning
