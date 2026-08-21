# 构建 Agent Harness

> 让模型能力转化为可靠执行，并探索当 Agent 可以连续工作，工具如何围绕人的注意力重新组织交互。

Hi，我是 Maisie。我在公开构建 **Agent Harness**。

我主要构建 Agent Runtime，并持续完善 Context Management、Goal、
Permission / Sandbox 和 Plugin。

我实现了 Goal：人定义目标、作出关键决策并验收结果，
Harness 接管中间的持续推进。

这也让我看到下一阶段的产品方向：当任务可以异步推进，
人的注意力会成为新的瓶颈，工具的交互重心也将从 Agent 的执行过程，
转向人的任务管理。

以下文章记录我如何实现和验证这些能力，
以及由此形成的工程与产品判断。

[查看 OpenHarness →](https://github.com/maisieyang/open-harness)

---

## 从这里开始

### 1. [Content Management：如何为 Coding Agent 管理有限注意力](./content-management.md)

**问题：模型下一次推理究竟应该看见什么？**

Context 不是记忆，而是 Harness 为每次推理编译的 Working Set。它必须持续选择、
限流、压缩和重建信息与能力。

### 2. [我实现了 `/goal`，但人还是不能离开](./goal-external-completion.md)

**问题：一个任务怎样在无人实时看守时持续推进，又不越过人的授权？**

Goal 让 Harness 自己接续每一轮；Permission 和 Sandbox 限制它能做什么、
实际能影响什么；真正需要人的决定则被保存，等待人回来处理。

### 3. [一个 Coding Agent，到底应该怎么验证？](./agent-eval-demystified.md)

**问题：我们凭什么相信 Agent 真的有效？**

TDD 锁定确定性机制，Eval 管理模型决策，Dogfood 与真实使用验证产品价值，
公共 Benchmark 补充一份有限的端到端证据。

### 4. [瓶颈在哪，交互重心就在哪](./coding-tools-evolution.md)

**问题：当 Agent 可以连续工作，交互重心为什么会从 REPL 走向 Task Management？**

Claude Code 释放 Agent 的行动能力，Goal 让单个任务可以异步推进；
Codex 则围绕人的调度、理解和验收重新组织交互。
当执行不再需要逐轮接棒，协作单位也从 turn 上移到 task。

### 5. [拆解 Anthropic 的产品逻辑](./anthropic-product-logic.md)

**问题：为什么 Harness 可能成为 AI 产品的战略层？**

从 Claude Code、统一 Harness、MCP、Plugin 和 Skill 出发，分析 Anthropic
如何把持续变强的模型接入高价值工作流。
