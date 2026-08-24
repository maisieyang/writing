<div class="home-intro">
  <p class="project-intro">
    Hi，我是 Maisie，一名有近 8 年前端与全栈经验、现专注 Coding Agent
    的产品工程师。我曾参与企业效率工具和复杂业务系统研发，过去两年持续投入
    LLM 与 Agent，目前正在独立构建
    <a class="github-project-link" href="https://github.com/maisieyang/open-harness" aria-label="OpenHarness on GitHub" title="OpenHarness on GitHub"><svg class="svg-icon" aria-hidden="true"><use xlink:href="{{ '/assets/minima-social-icons.svg#github' | relative_url }}"></use></svg><span>OpenHarness</span></a>。
  </p>

  <p class="project-summary">
    OpenHarness 是一个用 Python 从零实现、持续 Dogfood 的 local-first Coding Agent Harness。
  </p>

  <p class="project-focus">
    我的核心工作集中在 Agent Runtime，包括 Content Management、
    Default / Plan / Goal、Agent Interaction，以及 Eval。
    这些工作分别回答模型当前应该看见什么、在不同模式下可以采取什么行动、
    任务何时继续或停止、人何时需要介入，以及如何验证结果。
  </p>

  <div class="project-proof" aria-label="OpenHarness 验证数据">
    <p class="project-proof__date">
      OpenHarness 的测试、Eval 与 Benchmark 验证数据，截至 2026-08-22
    </p>
    <ul>
      <li><strong>2,791</strong> 个稳定测试</li>
      <li><strong>95.06%</strong> stable-core coverage</li>
      <li><strong>9</strong> 份 Eval contract · <strong>6 / 6</strong> replay gates</li>
      <li><strong>170 / 300</strong> SWE-bench Lite 基线</li>
    </ul>
  </div>

  <aside class="job-search">
    我目前正在寻找 Coding Agent、Agent Runtime、Agent 产品研发或 AI 全栈方向的工程职位。
    如果你们正在构建面向真实用户的 Agent，欢迎联系：
    <a href="mailto:maisieyang@outlook.com">maisieyang@outlook.com</a>
  </aside>
</div>

## 工程实践

以下文章来自我持续构建、使用和验证 OpenHarness 时遇到的真实工程问题。

### [我实现了 `/goal`，但人还是不能离开](./goal-external-completion.md)

**一个任务怎样在无人实时看守时持续推进，又不越过人的授权？**

我在 OpenHarness 中实现了 Goal Contract、Goal Controller 与独立 Judge，
让任务根据执行证据继续、完成或暂停；随后又将 Permission、Seatbelt / Docker
Sandbox 接入同一条控制路径，处理人离场后的授权与执行边界。

### [Content Management：如何为 Coding Agent 管理有限注意力](./content-management.md)

**模型下一次推理究竟应该看见什么？**

我把 Context 实现为 Harness 持续编译的 Working Set：组装 System Prompt 与
Tool Catalog，限制 Tool Result 增长，清理和压缩历史，并通过 Project Memory、Resume 管理跨 Session 的知识和状态。

### [一个 Coding Agent，到底应该怎么验证？](./agent-eval-demystified.md)

**当模型参与系统决策，我们凭什么相信 Agent 真的有效？**

我将验证拆成确定性的机制测试、模型参与的 Capability Eval、完整产品 Dogfood
和公共 Benchmark；并为 Eval 建立 Live、Record、Replay 与明确的证据有效边界。

## 产品思考

这些文章把 OpenHarness 中遇到的问题放回更广泛的产品变化与行业趋势中思考。

### [瓶颈在哪，交互重心就在哪](./coding-tools-evolution.md)

**当 Agent 可以连续工作，交互为什么会从 REPL 走向 Task Management？**

结合我对 Claude Code、Codex 的深度使用，以及在 OpenHarness 中实现 Goal
的经验，分析人的职责如何从逐轮推动执行，上移到定义目标、分配注意力和验收结果。

### [拆解 Anthropic 的产品逻辑](./anthropic-product-logic.md)

**为什么 Harness 可能成为 AI 产品的战略层？**

从 Claude Code 的演化、统一 Harness、MCP、Plugin 和 Skill 出发，分析
Anthropic 如何把持续变强的模型接入高价值工作流，并争夺企业工作的智能入口。
