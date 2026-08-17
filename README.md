# Writing

关于 Coding Agent、Agent Harness，以及技术变化如何重新塑造产品、工作与组织的长期写作。

这些文章来自我从 0 到 1 构建并持续 dogfood OpenHarness 的过程。它们不是功能文档，而是对
产品演化、系统边界和真实工程反馈的拆解。

## 产品与演化

| 文章 | 一句话 |
|---|---|
| [Claude Code 不是凭空出现的](./why-harness-2025.md) | agent harness 流行的底层条件：模型能力曲线如何把 prompt → context → harness → loop 一层层推过阈值 |
| [瓶颈在哪，交互重心就在哪](./coding-tools-evolution.md) | Terminal-first 释放 Agent 的行动能力；task-first 管理人的注意力：从同步 turn-taking 到 task control plane |
| [拆解 Anthropic 的产品逻辑](./anthropic-product-logic.md) | Claude Code 是长出来的不是规划出来的——Model + Harness + Plugin 分层系统的完整因果链 |

## Harness 工程复盘

| 文章 | 一句话 |
|---|---|
| [扩展 Coding Agent，不要扩展 Engine](./harness-plugin-substrate.md) | Plugin 不是第二套 runtime：外部能力如何被发现、翻译、命名并编译到既有 Skills、MCP、Hooks 与 QueryContext 契约中 |
| [我实现了 `/goal`，但人还是不能离开](./goal-external-completion.md) | Goal 接管长程任务的推进与停止之后，Permission、Sandbox 与 park/resume 如何让人的注意力真正离开执行循环 |
| [Content Management：如何为 Coding Agent 管理有限注意力](./content-management.md) | LLM 的输入不是记忆；Harness 通过选择、塑形、限流、压缩、外置和重建，为下一次推理编译可信且适配行动的 Working Set |
| [Agent Harness 的 Eval](./eval-engineering.md) | Eval 不是给模型打分，而是用能力声明、最硬 oracle、稳定性画像和 benchmark 为不可求导系统建立受控实验能力 |

## 工作、组织与机会

| 文章 | 一句话 |
|---|---|
| [理解组织之后，我开始重新理解机会](./understanding-organizations-and-opportunity.md) | 从完成 Task、害怕反馈，到理解所有权、因果半径，以及组织为什么设置一个职位所决定的真实契约与机会边界 |

## 相关项目

[build-my-own-harness](https://github.com/maisieyang/build-my-own-harness) ·
[finance-skills](https://github.com/maisieyang/finance-skills) ·
[my-skills](https://github.com/maisieyang/my-skills)
