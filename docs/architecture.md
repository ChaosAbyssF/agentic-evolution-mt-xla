# Architecture

This project is a Codex-oriented optimization harness, not a standalone model
training stack.

## High-Level Flow

```text
User target latency
  -> task.yaml
  -> remote benchmark
  -> hotspot inventory + backend map
  -> choose one optimization object
  -> local implementation improvement
  -> XLA rewriter -> custom call -> runtime target
  -> build/test
  -> whole-model benchmark
  -> lineage accept/reject
```

## Main Subsystems

### 1. Skill Layer

- Entry: `SKILL.md`
- Purpose: constrain Codex behavior so it optimizes the real TF2.15 + XLA path
- Key rule: do not accept local gains that do not reduce whole-model latency

### 2. Remote Execution Layer

- Main script: `scripts/remote_xla_exec.sh`
- Purpose: normalize local -> tmux/ssh -> docker exec access to the remote
  user-provided target container
- Modes:
  - `tmux`
  - `ssh`
  - `print`

### 3. Harness Layer

- `scripts/run_full_model.sh`
- `scripts/collect_op_inventory.sh`
- `scripts/run_xla_custom_call_checks.sh`
- `scripts/record_lineage.py`

Purpose:

- run baseline and candidate benchmarks
- initialize hotspot/backend knowledge
- validate XLA custom-call integration
- record accepted and rejected attempts

### 4. Knowledge Layer

- `knowledge/op_inventory.csv`
- `knowledge/backend_map.csv`
- `knowledge/pattern_db.yaml`
- `knowledge/error_db.yaml`
- `knowledge/perf_db.yaml`

Purpose:

- keep the optimization queue grounded in whole-model evidence
- make backend ownership explicit
- keep failures and performance signals reusable

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

## Acceptance Model

A lineage step is accepted only if all are true:

- correctness passes
- build/test path is healthy
- custom call path is hit
- whole-model latency improves

Everything else is a rejected attempt, even if the standalone kernel is faster.
