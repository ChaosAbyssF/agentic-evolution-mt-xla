# Architecture

This project is a Copilot-oriented optimization harness, not a standalone model
training stack.

## High-Level Flow

```text
User target latency
  -> task.yaml + operator_task.yaml
  -> operator optimization loop
  -> candidate worth integrating
  -> hotspot inventory + backend map
  -> XLA rewriter -> custom call -> runtime target
  -> build/test
  -> whole-model benchmark
  -> accept/reject or fall back to operator loop
```

## Main Subsystems

### 1. Skill Layer

- Entry: `SKILL.md`
- Purpose: constrain Copilot behavior so it optimizes the real TF2.15 + XLA path
- Key rule: do not accept local gains that do not reduce whole-model latency

### 2. Execution Layer

- Main script: `scripts/local_xla_exec.sh`
- Purpose: normalize command execution in the current local environment
- Modes:
  - `local`
  - `print`

### 3. Harness Layer

- `scripts/run_full_model.sh`
- `scripts/collect_op_inventory.sh`
- `scripts/run_xla_custom_call_checks.sh`
- `scripts/record_lineage.py`
- `scripts/operator_preflight.sh`
- `scripts/operator_correctness_benchmark.sh`
- `scripts/operator_profile_msys.sh`
- `scripts/export_msys_report.sh`
- `scripts/operator_generate_proposal.sh`
- `scripts/operator_prepare_next_seed.sh`
- `scripts/operator_record_result.py`
- `scripts/operator_select_best.sh`

Purpose:

- run operator and whole-model baselines
- drive the preflight -> correctness -> profiling -> proposal loop
- initialize hotspot/backend knowledge
- validate XLA custom-call integration
- record accepted and rejected attempts

### 4. Knowledge Layer

- `knowledge/op_inventory.csv`
- `knowledge/backend_map.csv`
- `knowledge/pattern_db.yaml`
- `knowledge/error_db.yaml`
- `knowledge/perf_db.yaml`
- `memory/semantic_ops.yaml`
- `memory/baselines.jsonl`
- `memory/operator_lineage.jsonl`
- `memory/integration_lineage.jsonl`

Purpose:

- keep the optimization queue grounded in whole-model evidence
- make backend ownership explicit
- keep failures and performance signals reusable
- persist operator semantics, baselines, and iteration history

### 5. XLA Integration Layer

The critical chain is:

1. optimized operator exists
2. MUSA HLO rewriter matches the pattern
3. HLO rewrites to `custom-call`
4. call is bridged through `musa_fusion_custom_calls`
5. GPU runtime resolves the registered target
6. MTGPU compiler runs the rewriter pass
7. BUILD graph links everything into the relevant plugin/JIT targets

Treat LayerNorm as the onboarding template for new operators.

## Operator Optimization Loop

The operator loop is now a first-class subsystem:

1. preflight environment and task checks
2. correctness plus local benchmark
3. targeted MSYS profiling
4. full MSYS profiling
5. bottleneck classification
6. optimization proposal generation
7. next-seed preparation
8. iteration result recording
9. best-version selection after the limit is reached

Important constraint:

- the loop stages are stable
- the MSYS profiling parameters are model-specific
- model-specific changes belong in `templates/operator_task.yaml`, not in the scripts

## Acceptance Model

A lineage step is accepted only if all are true:

- correctness passes
- build/test path is healthy
- custom call path is hit
- whole-model latency improves

Everything else is a rejected attempt, even if the standalone kernel is faster.

If the whole-model path does not improve, control returns to the operator loop
for another local optimization iteration.
