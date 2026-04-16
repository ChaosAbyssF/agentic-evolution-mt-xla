# File Structure

```text
agentic-evolution/
├── README.md
├── SKILL.md
├── config/
│   └── remote.env.example
├── docs/
│   ├── architecture.md
│   └── file-structure.md
├── evals/
│   └── evals.json
├── examples/
│   └── bench/
│       ├── bench_addn_eval.mu
│       └── bench_addn_eval.ref
├── knowledge/
│   ├── backend_map.csv
│   ├── error_db.yaml
│   ├── op_inventory.csv
│   ├── pattern_db.yaml
│   └── perf_db.yaml
├── memory/
│   ├── baselines.jsonl
│   ├── integration_lineage.jsonl
│   ├── operator_lineage.jsonl
│   └── semantic_ops.yaml
├── references/
│   ├── optimization-patterns.md
│   ├── platform-cuda.md
│   ├── platform-musa.md
│   ├── remote-environment.md
│   └── xla-custom-call-flow.md
├── research/
│   └── papers/
│       └── 2603.24517v1.pdf
├── scripts/
│   ├── collect_op_inventory.sh
│   ├── export_msys_report.sh
│   ├── install_skill.sh
│   ├── operator_correctness_benchmark.sh
│   ├── operator_generate_proposal.sh
│   ├── operator_prepare_next_seed.sh
│   ├── operator_preflight.sh
│   ├── operator_profile_msys.sh
│   ├── operator_record_result.py
│   ├── operator_select_best.sh
│   ├── record_lineage.py
│   ├── remote_xla_exec.sh
│   ├── run_full_model.sh
│   └── run_xla_custom_call_checks.sh
├── templates/
│   ├── operator_task.yaml
│   └── task.yaml
└── artifacts/
```

## Directory Roles

### Root

- `README.md`: project-level overview and first commands
- `SKILL.md`: Codex-facing behavior contract

### `config/`

User-owned environment configuration templates. These files define remote host,
container, tmux session, and workspace values without hardcoding them into the
project.

### `docs/`

Human-facing project docs:

- architecture
- layout
- project intent

### `evals/`

Prompt-level regression cases for the skill itself.

### `examples/`

Small assets and example kernels. These are not the production benchmark path.

### `knowledge/`

Working state for:

- hotspot ranking
- backend ownership
- optimization hints
- known failures
- reusable performance signals

### `memory/`

Persistent facts and iteration history for:

- semantic operators
- user-provided and measured baselines
- operator optimization lineage
- XLA integration lineage

### `references/`

Stable reference material the skill depends on:

- platform notes
- XLA custom-call flow
- optimization patterns

### `research/`

Papers and external background material. Kept out of the main execution path.

### `scripts/`

Executable harness pieces. These are the operational heart of the project.

### `templates/`

Input templates for a real optimization task.

- `task.yaml`: whole-model and XLA integration task
- `operator_task.yaml`: operator optimization loop task

### `artifacts/`

Generated outputs from runs, such as benchmark logs and summaries.
