# Execution Environment Contract

This skill assumes all commands are executed directly in the current local
environment.

## User-Provided Settings

This project does not hardcode workspace paths. The user provides the local
workspace root.

Recommended mechanism:

- copy `config/local.env.example` to `config/local.env`
- fill in the real values
- set `AE_ENV_FILE=./config/local.env`

Required value:

- `AE_LOCAL_WORKDIR`

## Key Repositories and Trees

- `tf_openxla_mtgpu`
- `model/meta_graph_2`
- `scripts/common_runner.sh`
- `scripts/0.build_musa_xla.sh`

## Toolchain

- System MUSA SDK: `/usr/local/musa-4.3.5`
- Expected execution style: `bash -lc 'cd <workdir> && <command>'`

## Operational Rules

- Do not claim a performance win without local whole-model validation.
- Do not treat CUDA or L20 PTX data as the final benchmark signal.
- Keep the benchmark command stable across baseline and candidate runs.
- Use `avg_latency_ms` from `outputs/*/common_runner.log` as the primary metric.
- Baseline reference: `result_graph2.md` -> `w_musa_xla` at `bsz=1024` (`457.706 ms`).
- Default validation batch size is `1024` unless the user explicitly overrides it.
- After each code change and `scripts/common_runner.sh` run, write
  `experiment_log.md` into that run's output directory.
- Reusable check interfaces:
  - `scripts/run_musa_rewriter_test.sh`
  - `scripts/run_musa_custom_call_test.sh`
  - `scripts/operator_model2_eval.sh`
  - `scripts/operator_task_bootstrap.sh`

## Recommended Control Loop

1. Confirm the skill is running in the intended local environment.
2. Run benchmark/build/test commands from `AE_LOCAL_WORKDIR`.
3. Capture stdout/stderr into artifacts.
4. Record the accepted lineage step.

Use `../scripts/local_xla_exec.sh` to standardize these local calls.
