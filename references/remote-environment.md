# Remote Environment Contract

This skill assumes the real execution environment is remote and must be treated
as the single source of truth for performance claims.

## User-Provided Remote Settings

This project no longer hardcodes the remote host, user, password, container, or
workspace path. The user must provide them.

Recommended mechanism:

- copy `config/remote.env.example` to `config/remote.env`
- fill in the real values
- set `AE_REMOTE_ENV_FILE=./config/remote.env`

Required values:

- `AE_REMOTE_HOST`
- `AE_REMOTE_CONTAINER`
- `AE_REMOTE_WORKDIR`
- `AE_TMUX_SESSION` when using tmux mode

## Key Repositories and Trees

- `tf_openxla_mtgpu`
- `tensorflow_musa_extension`
- `musa-4.3.5`
- `tf_test_model`
- `xla_musa`

## Toolchain

- System MUSA SDK: `/usr/local/musa-4.3.5`
- Expected control surface: `tmux`
- Expected execution style: `docker exec -i <user_container> bash -lc '...'`

## Operational Rules

- Do not claim a performance win without remote validation in the user-provided
  target container.
- Do not use local benchmark output as the acceptance metric.
- Do not treat CUDA or L20 PTX data as the final benchmark signal.
- Keep the benchmark command stable across baseline and candidate runs.

## Recommended Local Control Loop

1. Connect to the remote shell through tmux
2. Enter the container
3. Run benchmark/build/test commands from the remote workspace root
4. Capture stdout/stderr into local artifacts
5. Record the accepted lineage step

Use `../scripts/remote_xla_exec.sh` to standardize these calls.
