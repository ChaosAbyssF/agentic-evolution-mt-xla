---
name: agentic-evolution
description: |
  Optimize TensorFlow 2.15 whole-model inference on Moore Threads MUSA by
  driving a remote XLA workflow with Codex. Use when the real goal is lowering
  end-to-end latency, and optimized operators must be wired into XLA through
  MUSA GPU custom calls so the whole network actually speeds up.
---

# Agentic Evolution for TF2.15 + MUSA + XLA Custom Calls

This skill turns Codex into a whole-model latency optimizer for the remote MUSA
environment. It keeps the useful AVO ideas:

- lineage over accepted attempts
- feedback-driven iteration
- stagnation detection
- knowledge-first optimization

But it changes the objective:

- Do **not** optimize isolated kernels as the final goal
- Do **not** accept local or CUDA-only wins as success
- Do optimize the real TF2.15 inference path
- Do integrate wins into XLA through **custom calls**

## Use This Skill When

- The target environment is Moore Threads MUSA
- The performance goal is whole-network TF2.15 inference latency
- Optimized operators must bypass default XLA lowering
- The integration path is:
  optimized operator -> XLA rewriter -> custom call -> runtime target -> whole-model benchmark

## Canonical Remote Environment

The remote environment is user-provided.

Required inputs:

- remote host/user
- target container
- remote workspace root
- tmux session name when using tmux mode
- actual repository roots inside the workspace

Recommended setup:

- copy `config/remote.env.example` to `config/remote.env`
- fill in the real values
- export `AE_REMOTE_ENV_FILE=./config/remote.env`

Use `scripts/remote_xla_exec.sh` as the local launcher for remote container
commands. Default mode is tmux because the remote workflow is interactive and
long-running.

## Non-Negotiable Goal

The only success metric is **whole-model latency reduction** in the remote
user-provided environment.

Local wins are insufficient on their own:

- faster standalone kernel but no XLA integration -> not accepted
- XLA rewrite created but runtime target not hit -> not accepted
- custom call hit but whole-model latency unchanged -> not accepted
- CUDA or L20 PTX-only gain without MUSA confirmation -> not accepted

## Project Layout

This skill is packaged as a full project.

Read for orientation:

- `README.md`
- `docs/architecture.md`
- `docs/file-structure.md`
- `references/remote-environment.md`
- `references/xla-custom-call-flow.md`

## Core Workflow

### 1. Establish the Baseline

Run the real TF2.15 model benchmark first.

- Use `templates/task.yaml` to define the benchmark command
- Save outputs under `artifacts/run_<timestamp>/`
- Record:
  - container
  - benchmark command
  - target latency
  - measured latency or throughput
  - correctness result

Use:

    scripts/run_full_model.sh templates/task.yaml

### 2. Build the Optimization Queue

Do not pick operators by guesswork.

Collect:

- hotspot list
- call counts
- tensor shapes and dtypes
- current backend owner
- expected whole-model contribution

Initialize or update:

- `knowledge/op_inventory.csv`
- `knowledge/backend_map.csv`
- `knowledge/pattern_db.yaml`
- `knowledge/error_db.yaml`
- `knowledge/perf_db.yaml`

Use:

    scripts/collect_op_inventory.sh templates/task.yaml

### 3. Optimize One Target at a Time

For each iteration, choose exactly one primary optimization object:

- runtime/backend overhead
- `muDNN` / `muBLAS` path
- existing custom fused op
- new custom fused op or kernel

Never mix multiple primary changes in the same accepted step. Keep attribution
clean enough that whole-model regressions remain explainable.

### 4. Integrate Through XLA Custom Call

This is the critical path for whole-model wins.

For any optimized operator, follow the LayerNorm template:

1. Add or adapt the optimized implementation
2. Add a MUSA HLO rewriter that matches the target pattern
3. Rewrite the HLO to a `custom-call`
4. Bridge the call in `musa_fusion_custom_calls.cc/.h`
5. Ensure the runtime can resolve the target via GPU custom call registration
6. Insert the pass into the MTGPU compiler pipeline
7. Add BUILD deps and tests

Reference files:

- `third_party/xla/xla/service/gpu/runtime/custom_call.cc`
- `tensorflow/compiler/jit/BUILD`
- `third_party/xla/xla/service/gpu/BUILD`
- `third_party/xla/xla/service/gpu/mtgpu_compiler.cc`
- `third_party/xla/xla/service/gpu/musa_fusion_custom_calls.cc`
- `third_party/xla/xla/service/gpu/musa_fusion_custom_calls.h`
- `third_party/xla/xla/service/gpu/musa_fusion_custom_calls_test.cc`
- `third_party/xla/xla/service/gpu/musa_layer_norm_rewriter.h`
- `third_party/xla/xla/service/gpu/musa_layer_norm_rewriter_test.cc`

Read:

- `references/xla-custom-call-flow.md`
- `references/remote-environment.md`

### 5. Validate the XLA Integration Chain

Every candidate must prove the entire chain:

- optimized implementation is correct
- rewriter test passes
- custom call test passes
- BUILD graph still compiles
- runtime resolves the target
- whole-model benchmark improves

Use:

    scripts/run_xla_custom_call_checks.sh templates/task.yaml

### 6. Accept or Reject the Attempt

Only accept a lineage step when:

- correctness passes
- the custom call path is hit
- whole-model latency improves or meets the target

Record every attempt in `lineage.jsonl` with:

- target operator
- files touched
- local result
- XLA integration result
- whole-model result
- accept/reject decision

Use:

    python3 scripts/record_lineage.py ...

## LayerNorm Template

Treat LayerNorm as the canonical pattern for future operators.

For a new target op:

1. Inspect the LayerNorm rewriter shape and trigger conditions
2. Mirror its rewrite style for the new op
3. Register the new custom call using the same GPU runtime bridge pattern
4. Add tests at the rewriter and custom call levels
5. Prove the new op now bypasses default XLA lowering in the real model path

Do not invent a different integration style unless the target op genuinely
requires it.

## Local Helper Scripts

- `scripts/remote_xla_exec.sh`
  local -> tmux/ssh -> remote container launcher
- `scripts/run_full_model.sh`
  baseline/candidate benchmark wrapper
- `scripts/collect_op_inventory.sh`
  hotspot and backend-map capture scaffold
- `scripts/run_xla_custom_call_checks.sh`
  build/test wrapper for rewriter and custom-call integration
- `scripts/record_lineage.py`
  append-only lineage recorder

## Required Artifacts

Each run must create:

- `artifacts/run_<timestamp>/<run_label>.log`
- `artifacts/run_<timestamp>/correctness.log`
- `artifacts/run_<timestamp>/summary.json`
- `lineage.jsonl`

Knowledge files should live under:

- `knowledge/op_inventory.csv`
- `knowledge/backend_map.csv`
- `knowledge/pattern_db.yaml`
- `knowledge/error_db.yaml`
- `knowledge/perf_db.yaml`

## Default Decision Rules

- Prioritize whole-model impact over local prettiness
- Prefer existing backend and library paths before inventing new kernels
- Use L20/PTX data only as inspiration, never as the acceptance signal
- If a local gain does not survive XLA integration, abandon that path
- If progress stalls, review lineage before trying another micro-optimization

## First Command Set

For a new task, the minimum useful sequence is:

    cp config/remote.env.example config/remote.env
    export AE_REMOTE_ENV_FILE=./config/remote.env
    AE_RUN_LABEL=baseline scripts/run_full_model.sh templates/task.yaml
    scripts/collect_op_inventory.sh templates/task.yaml
    scripts/run_xla_custom_call_checks.sh templates/task.yaml

Then pick one hotspot, integrate it through the LayerNorm-style custom call
path, and rerun `AE_RUN_LABEL=candidate scripts/run_full_model.sh`.
