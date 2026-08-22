<p class="project-intro">
  Hi，我是 Maisie。我在公开构建：
  <a class="github-project-link" href="https://github.com/maisieyang/open-harness" aria-label="OpenHarness on GitHub" title="OpenHarness on GitHub"><svg class="svg-icon" aria-hidden="true"><use xlink:href="{{ '/assets/minima-social-icons.svg#github' | relative_url }}"></use></svg><span>OpenHarness</span></a>。
</p>
<p>我构建模型周围的系统，让模型能力转化为可靠执行。</p>
<p>我实现了Agent Runtime、Context Management、Goal、Permission / Sandbox 与 Plugin 扩展。</p>
<p>目前正在寻找 Agent Harness 与 Coding Agent 系统方向的工程机会。 Email：<a href="mailto:yangxiyuebupt@gmail.com">yangxiyuebupt@gmail.com</a></p>

## 研究与实践

### 1. [Content Management：如何为 Coding Agent 管理有限注意力](./content-management.md)

**模型下一次推理究竟应该看见什么？**

Context 不是记忆，而是 Harness 为每次推理编译的 Working Set。它必须持续选择、
限流、压缩和重建信息与能力。

### 2. [我实现了 `/goal`，但人还是不能离开](./goal-external-completion.md)

**一个任务怎样在无人实时看守时持续推进，又不越过人的授权？**

Goal 让 Harness 自己接续每一轮；Permission 和 Sandbox 限制它能做什么、
实际能影响什么；真正需要人的决定则被保存，等待人回来处理。

### 3. [一个 Coding Agent，到底应该怎么验证？](./agent-eval-demystified.md)

**我们凭什么相信 Agent 真的有效？**

TDD 锁定确定性机制，Eval 管理模型决策，Dogfood 与真实使用验证产品价值，
公共 Benchmark 补充一份有限的端到端证据。

### 4. [瓶颈在哪，交互重心就在哪](./coding-tools-evolution.md)

**当 Agent 可以连续工作，交互重心为什么会从 REPL 走向 Task Management？**

Claude Code 释放 Agent 的行动能力，Goal 让单个任务可以异步推进；
Codex 则围绕人的调度、理解和验收重新组织交互。
当执行不再需要逐轮接棒，协作单位也从 turn 上移到 task。

### 5. [拆解 Anthropic 的产品逻辑](./anthropic-product-logic.md)

**为什么 Harness 可能成为 AI 产品的战略层？**

从 Claude Code、统一 Harness、MCP、Plugin 和 Skill 出发，分析 Anthropic
如何把持续变强的模型接入高价值工作流。
