# 当人离开 Agent Loop

我从零构建 OpenHarness，研究模型之外那层真正决定 Coding Agent
能否承担长程工作的系统：


OpenHarness 是一个用 Python 构建、local-first 的 Coding Agent control plane。
以下文章不是对现有框架的功能介绍，而是我在实现、Dogfood、Eval 和 Benchmark
过程中形成的一套判断。

[查看 OpenHarness →](https://github.com/maisieyang/open-harness)

---

## 从这里开始

### 1. [我实现了 `/goal`，但人还是不能离开](./goal-external-completion.md)

**问题：人怎样离开 Agent Loop，又不失去控制？**

Goal 可以接管任务的持续推进与完成判断，但人离场以后，Permission、
Sandbox 和 Park 还必须共同承担行动边界。

### 2. [Content Management：如何为 Coding Agent 管理有限注意力](./content-management.md)

**问题：长程任务中，模型下一次推理究竟应该看见什么？**

Context 不是记忆，而是每次推理的 Working Set。Harness 必须不断选择、
限流、压缩和重建信息与能力。


### 3. [一个 Coding Agent，到底应该怎么验证？](./agent-eval-demystified.md)

**问题：我们凭什么相信 Agent 真的有效？**

TDD 锁定确定性机制，Eval 管理模型决策，Dogfood 暴露未知问题，
公共 Benchmark 提供外部坐标。

### 4. [拆解 Anthropic 的产品逻辑](./anthropic-product-logic.md)

**问题：为什么 Harness 可能成为 AI 产品的战略层？**

从 Claude Code、统一 Harness、MCP、Plugin 和 Skill 出发，分析 Anthropic
如何把持续变强的模型接入高价值工作流。

---

## OpenHarness 的证据基线

我用三类证据判断 OpenHarness 是否可靠：软件机制是否稳定、Agent 决策是否符合契约，以及完整系统在外部任务上的表现。

- **软件机制**：共收集 2,792 个测试项，其中 2,775 个通过，17 个按当前配置未运行；Branch coverage 为 95.11%。Ruff、format 和 `mypy --strict` 全部通过，CI 覆盖 Python 3.10 与 3.11。
- **Agent 决策**：9 份 capability eval contract 定义了关键行为应该如何被验证；6 个经过真实模型运行确认的 replay gates 全部通过。
- **外部任务**：OpenHarness 在 2026-07-12 的 SWE-bench Lite 基线上解决了 170 / 300 个任务，resolved rate 为 56.7%。

---

## 核心判断

> 模型负责智能，Harness 对行动的后果负责。

> 长程 Agent 的关键，不是让模型运行更多轮，
> 而是让人可以离开，又不失去控制。

> Eval 是把人的品味变成工程资产。
