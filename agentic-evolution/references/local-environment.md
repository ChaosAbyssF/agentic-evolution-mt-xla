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
- `tensorflow_musa_extension`
- `musa-4.3.5`
- `tf_test_model`
- `xla_musa`

## Toolchain

- System MUSA SDK: `/usr/local/musa-4.3.5`
- Expected execution style: `bash -lc 'cd <workdir> && <command>'`

## Operational Rules

- Do not claim a performance win without local whole-model validation.
- Do not treat CUDA or L20 PTX data as the final benchmark signal.
- Keep the benchmark command stable across baseline and candidate runs.

## Recommended Control Loop

1. Confirm the skill is running in the intended local environment.
2. Run benchmark/build/test commands from `AE_LOCAL_WORKDIR`.
3. Capture stdout/stderr into artifacts.
4. Record the accepted lineage step.

Use `../scripts/local_xla_exec.sh` to standardize these local calls.
