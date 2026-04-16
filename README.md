# 面向 TF2.15 + MUSA + XLA Custom Call 的 Agentic Evolution

这个项目把 `agentic-evolution` skill 封装成了一套可直接供 Codex 使用的完整工作流，目标在摩尔线程 MUSA 平台上，通过 XLA custom call 把优化后的算子接入 TensorFlow 2.15 的真实执行链路，从而降低整网推理时延。

## 具体过程

1. 在远端容器中测量整网 baseline
2. 识别热点算子及其当前后端归属
3. 每次只优化一个目标
4. 通过 XLA custom call 把优化实现接进整网
5. 重建、验证，并重新跑整网 benchmark
6. 只保留真正降低端到端时延的尝试

## 项目内容

- Codex skill 入口：[SKILL.md](./SKILL.md)
- 远端执行与 benchmark 脚本：[scripts/](./scripts)
- XLA custom call 接入说明：[references/](./references)
- 项目文档与目录说明：[docs/](./docs)
- 任务模板与知识库骨架：[templates/](./templates)、[knowledge/](./knowledge)
- 示例 benchmark 资源：[examples/](./examples)
- 研究参考材料：[research/](./research)

## 用户需要自己提供的内容

这个项目不再硬编码任何远端用户名、主机、密码、容器名或工作区路径。你需要自己提供：

- 远端登录信息
  - 主机地址
  - 用户名
  - 认证方式
  - 如果你走密码登录，由你自己在外部终端/tmux 中完成认证
- 远端运行环境
  - 目标容器名
  - 远端工作区根目录
  - 实际使用的 MUSA SDK 路径
- 远端代码树位置
  - `tf_openxla_mtgpu`
  - `tensorflow_musa_extension`
  - `musa-4.3.5`
  - `tf_test_model`
- 任务级输入
  - 目标整网时延
  - 你认可的 baseline
  - 整网 benchmark 命令
  - correctness 命令
  - hotspot trace 命令
  - build 命令
  - rewriter test 命令
  - custom call test 命令

推荐做法：

1. 复制 [config/remote.env.example](./config/remote.env.example) 为 `config/remote.env`
2. 填入你自己的远端信息
3. 在运行前导出：

   ```bash
   export AE_REMOTE_ENV_FILE=./config/remote.env
   ```

唯一被接受的性能信号，是**你提供的远端环境**中的整网结果。

## 快速开始

1. 先复制并填写远端配置：

   ```bash
   cp ./config/remote.env.example ./config/remote.env
   export AE_REMOTE_ENV_FILE=./config/remote.env
   ```

2. 再把真实任务命令填进 [templates/task.yaml](./templates/task.yaml)
3. 跑一次 baseline：

   ```bash
   AE_RUN_LABEL=baseline ./scripts/run_full_model.sh ./templates/task.yaml
   ```

4. 初始化热点和后端映射：

   ```bash
   ./scripts/collect_op_inventory.sh ./templates/task.yaml
   ```

5. 跑 XLA custom call 的 build/test 检查：

   ```bash
   ./scripts/run_xla_custom_call_checks.sh ./templates/task.yaml
   ```

6. 选择一个热点，按 LayerNorm 风格的 custom call 路径接入，然后重跑整网并记录结果：

   ```bash
   AE_RUN_LABEL=candidate ./scripts/run_full_model.sh ./templates/task.yaml
   python3 ./scripts/record_lineage.py \
     --target-op layernorm \
     --decision accepted \
     --summary "示例 lineage 记录"
   ```

## 核心规则

单算子更快并不够。一个 candidate 只有在同时满足下面条件时才算成功：

- correctness 通过
- XLA custom call 路径真正命中
- 整网时延下降

## 建议继续阅读

- [docs/architecture.md](./docs/architecture.md)
- [docs/file-structure.md](./docs/file-structure.md)
- [references/xla-custom-call-flow.md](./references/xla-custom-call-flow.md)
