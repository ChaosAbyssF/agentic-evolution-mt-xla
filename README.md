# 面向 TF2.15 + MUSA + XLA Custom Call 的 Agentic Evolution

这个项目把 `agentic-evolution` skill 封装成了一套可直接供 Codex 使用的完整工作流，目标是在摩尔线程 MUSA 平台上，通过 **算子优化闭环 + XLA custom call 接入闭环** 两段流程，把优化后的算子接入 TensorFlow 2.15 的真实执行链路，从而降低整网推理时延。

## 工作流总览

### 闭环 A：算子优化闭环

这部分严格按固定步骤运行：

1. `Preflight` 环境检查
2. `Correctness + Benchmark`
3. 通过则进入 `Targeted MSYS profiling`
4. 再进入 `Full MSYS profiling`
5. 根据统计结果做瓶颈分类诊断
6. 生成 `optimization_proposal.md`
7. 产出下一版种子 `iter_v0 -> iter_v1 -> iter_v2`
8. 记录本轮结果：`positive / negative / rejected`
9. 达到上限后选出最佳版本，生成 `final_summary.md` 和 `run_manifest_index.txt`

### 闭环 B：XLA 接入闭环

只有当算子优化闭环产出了值得接入的候选后，才进入：

1. HLO rewriter 接入
2. custom call bridge 接入
3. runtime target 命中验证
4. whole-model benchmark
5. 若整网无收益，则回退到闭环 A 继续优化

## 项目内容

- Codex skill 入口：[SKILL.md](./SKILL.md)
- 远端执行与 benchmark 脚本：[scripts/](./scripts)
- XLA custom call 接入说明：[references/](./references)
- 项目文档与目录说明：[docs/](./docs)
- 任务模板与知识库骨架：[templates/](./templates)、[knowledge/](./knowledge)、[memory/](./memory)
- 示例 benchmark 资源：[examples/](./examples)
- 研究参考材料：[research/](./research)

## 如何下载这个项目

直接克隆仓库：

```bash
git clone https://github.com/Aloyshaaaa/-agentic-evolution-musa.git
cd agentic-evolution-musa
```

如果你使用 SSH：

```bash
git clone git@github.com:Aloyshaaaa/-agentic-evolution-musa.git
cd agentic-evolution-musa
```

## 如何安装成 Codex skill

推荐安装方式是用项目自带脚本创建软链接：

```bash
./scripts/install_skill.sh
```

默认会把当前项目链接到：

```text
~/.codex/skills/agentic-evolution
```

如果你想安装到别的名字：

```bash
./scripts/install_skill.sh ~/.codex/skills/agentic-evolution-musa
```

安装后如果 Codex 已经在运行，重启一次 Codex 让 skill 列表刷新。

## 如何和 Codex 对话来调用这个 skill

推荐用法是直接在对话里明确提到 skill 名和任务目标，例如：

```text
使用 agentic-evolution skill，针对 layernorm_fwd 做同语义 MUSA 算子优化，并在通过后接入 XLA custom call，最后验证整网时延是否下降。
```

或者：

```text
用 agentic-evolution 帮我做 attention_qk_softmax_pv 的算子优化。先跑 preflight、correctness、msys targeted/full profiling，再给出 proposal，最后如果局部性能达标就接入 XLA。
```

你也可以明确要求它只跑某一段闭环，例如：

```text
使用 agentic-evolution skill，只执行算子优化闭环，不做 XLA 接入。输出 targeted/full msys profiling、瓶颈诊断和下一版 proposal。
```


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
  - PTX 语义说明
  - 算子优化 seed 路径
  - operator correctness / benchmark 命令
  - operator profiling 参数
    - profiling workdir
    - duration
    - target
    - report prefix
    - run command
    - stats reports
    - export prefix

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

2. 再把真实任务命令填进：
   - [templates/task.yaml](./templates/task.yaml)
   - [templates/operator_task.yaml](./templates/operator_task.yaml)
3. 调用skill


## 建议继续阅读

- [docs/architecture.md](./docs/architecture.md)
- [docs/file-structure.md](./docs/file-structure.md)
- [references/xla-custom-call-flow.md](./references/xla-custom-call-flow.md)
