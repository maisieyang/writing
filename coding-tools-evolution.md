# 瓶颈在哪，交互重心就在哪：coding 工具四代变迁的一手记录

> 写于 2026-07-31
> 起点是我自己的迁移史：ChatGPT → Cursor → Claude Code → Codex app，四次换工具，每次都不是因为"新工具功能多"，而是因为旧交互突然不顺了。这篇把这条体感主线补上调研事实，看清楚背后的规律。

## 引子：我的四次迁移

最早是 ChatGPT，chat 的形式，在浏览器和 IDE 之间来回搬代码。然后 Cursor 出来，觉得真好用——因为那个当下工作的起点是以代码为中心，Cursor 是很棒的 copilot。后来模型越来越强，我开始用 Claude Code 就不再用 Cursor 了：交互的重点转移了，agent 要写绝大部分的代码，**agent 是主体，不是代码**。terminal 天然适合多 session、多任务，作为程序员，在 terminal 里做这一切都很自然。

然后我发现它不顺了。模型生成代码的速度明显超出了我的注意力可以 review 的范围。terminal 的 REPL 让我的体感开始变差：我在阅读的时候它在生成，页面会跳，我滚回去，它又生成，又跳。我把 terminal 放大到屏幕 70% 的面积，阅读体验还是不好。我跟不上它的实现细节，但我还不能离开——我需要不停地接 turn，机械地接，大多数只是 approve。

深度体验了两天 Codex app 之后，我知道这就是我目前想要的：左侧是任务管理，中心最好的位置给任务的信息交互流，右侧是可收起的 diff review 面板。关注点在 task 时有完美的阅读体验；要 check 代码改动时打开右侧栏——不是代码仓浏览器，是**这一次任务的改动**。关注点分离做到了极致，这是一个能让人产生心流的工具。

四次迁移，四个当下，每个当下都有更适合的工具。这背后的规律是什么？

## 总命题

**每一代工具的形态，都不是设计品味的选择，而是对"当时模型参数下，人的注意力该花在哪"的精确适配。** 模型能力每上一个台阶，稀缺的判断就换一个位置，界面就围绕新的稀缺判断重组。

还有一条贯穿的暗线：**每一代的"暴露问题"都是上一代成功制造的**。copy-paste 的摩擦只有在 chat 真的有用之后才存在；review 瓶颈只有在 agent 真的高产之后才存在。瓶颈不消失，只迁移。

下面按"朴素方案 → 暴露问题 → 下一修复"的链条走四代。

---

## 第一代：Chat + Ghost Text（2021-2023）——人是 context 搬运工

**朴素方案**：模型给建议，人做一切其他事。两种形态：[GitHub Copilot](https://github.blog/news-insights/product-news/introducing-github-copilot-ai-pair-programmer/)（2021.6，官方定位 "AI pair programmer"，能力上限写明是"补全整行或整个函数"）的 ghost text，和 ChatGPT（2022.11）的 copy-paste 编程。

**为什么这是当时的唯一解**——有组很锋利的数字：Copilot 底层的 Codex 模型 [HumanEval pass@1 只有 28.8%](https://arxiv.org/abs/2107.03374)，GPT-3.5 上下文只有 4k tokens。由此直接推出三重约束：

1. **4k 装不下工程现场**——模型物理上看不到代码库，只能由人裁剪、搬运上下文。copy-paste 不是产品设计失误，是根因。
2. **单步成功率撑不起多步链条**——pass@1 三成，五步无人验证的链条成功率是百分之几的量级。"人做每一步验证"不是选择，是数学必然。行为学研究（[Grounded Copilot](https://arxiv.org/pdf/2206.15000)）证实：程序员花大量时间像 code review 一样阅读建议，验证责任 100% 在人。
3. **没有行动通道**——没有工具调用、没有执行环境。

Ghost text 是对这三个参数的精确适配：建议大概率是错的 → 把"拒绝"的成本压到零（继续打字即忽略），把"接受"压到一个 Tab。**低命中率 × 零成本拒绝，是这组模型参数下唯一成立的交互。**

**暴露问题**：GPT-4（pass@1 67%）之后，建议值得要了，但人肉搬运 context 的摩擦成了主要成本。2023 年 HN 上全是"我受够了 copy-paste 所以做了个工具"的帖子；Aider 作者在[当时的讨论](https://news.ycombinator.com/item?id=36211250)里的名言："Don't copy-and-paste between a chat session and your files"。瓶颈位置：**把模型接到工程现场**。

## 第二代：Cursor（2023-2025）——把模型搬进代码的主场

**修复方案**：既然人不该做搬运工，就把模型嵌进 IDE，让它自己看到代码库。Cursor 的关键决策是 [fork VS Code 而不是做插件](https://www.mmntm.net/articles/cursor-deep-dive)——插件 API 给不了自定义 UI（inline diff 覆盖层）和深度上下文（codebase indexing），要拿开发者工作流的 "root access"。这个决策在 2023 年是对的，因为**工作重心还在编辑器缓冲区里**：人仍是主要写码者，AI 的价值只能以"贴着光标的交互"（Tab、Cmd+K）交付。

**与模型跃迁的精确咬合**：2024-06-20 Claude 3.5 Sonnet 发布（SWE-bench Verified 49%，首个能可靠做多文件编码的模型）→ 三周后 Cursor 发 [Composer beta](https://cursor.com/en/changelog/composer-beta-)（多文件编辑）→ 11 月 [Agent 模式](https://cursor.com/en/changelog/new-composer-ui-agent-commit-messages)上线。ARR 从 2023 底 $1M 冲到 2025.1 $100M、2025.11 [$1B——史上最快](https://sacra.com/c/cursor/)。这条曲线就是"交互形态 × 模型能力窗口"红利的定价。

**暴露问题**：agent 写绝大部分代码后，**编辑器面积本身成了负资产**。2025 年 HN 迁移潮里最反直觉的一条评论："Claude is just better at coding... [the interface isn't meaningful](https://news.ycombinator.com/item?id=45789738)"——迁移者自己说界面不是重点，说明 IDE 界面已不构成留人的理由。典型状态是"[Cursor 降级为看 diff 的壳，干活的是终端里的 Claude Code](https://www.builder.io/blog/cursor-vs-claude-code)"。Cursor 的应对是自我否定式的：2025.8 出 CLI（复刻 Claude Code 形态），[2.0](https://cursor.com/blog/2-0) 把主界面从编辑器改成多 agent 面板。**形态红利随模型跃迁转移，UI 不构成护城河。**

值得记一笔的是 Michael Truell 自己的表述（[Lenny's Podcast](https://www.lennysnewsletter.com/p/the-rise-of-cursor-michael-truell)）：Cursor 的目标是 "invent a new type of programming"，从代码中心到意图中心；但他同时反对纯 chat 界面——"code is too tedious but prompting is too chaotic"，人需要对逻辑保留精确控制面。这句话解释了 Cursor 在 agent 化的同时为何不放弃可视化 diff——也预告了第四代里 review 面板的位置。

## 第三代：Claude Code（2025）——agent 为主体，终端是它的自然居所

**修复方案**：既然主体换位了，就把界面从"人的写码环境"换成"agent 的行动环境"。前驱是 [Aider](https://github.com/Aider-AI/aider)（2023.5，"AI pair programming in your terminal"，git 原生），证明终端这条线早两年就存在，但它停在 pair programming；agent 主体性是 Claude Code（2025.2 research preview）补上的那一半。

Boris Cherny 的设计哲学原话（[Latent Space 播客](https://www.latent.space/p/claude-code)）："It's **raw access to the model**... we literally could not build anything more minimal"、"we think of it as a **Unix utility**"。刻意不建 "big beautiful UI"，因为 UI 会遮蔽模型行为——薄 harness 是为强模型设计的。

终端形态免费送出两样东西：**并行**（多 tab / tmux / git worktrees，Cherny 自称 [worktree 并行是 "single biggest productivity unlock"](https://codewithmukesh.com/blog/git-worktrees-claude-code/)）和**可组合**（管道、`-p` headless、CI、脚本化）。行业四个月内收敛确认了共识：Anthropic 2025.2 → OpenAI Codex CLI 2025.4 → Gemini CLI 2025.6。

**暴露问题**——我的体感有两层，两层都有实锤：

- **物理层**：终端滚动跳动、流式输出覆盖手动回滚、阅读被生成打断——这是 claude-code 官方 repo 里 [700+ 赞、拖了 9 个月的著名 issue](https://github.com/anthropics/claude-code/issues/34845)，不是个人敏感。
- **认知层**：[GitLab 调查 85% 的受访者认为瓶颈已从写代码转移到 review](https://thenewstack.io/merge-gate-coding-agents/)；Addy Osmani 的表述几乎和体感逐字一致："[The bottleneck is no longer how fast you write code, it is how fast a trusted human can be confident in a review](https://addyosmani.com/blog/agentic-code-review/)"。同步 REPL 把人绑在 turn-taking 上，大多数 turn 只是 approve——社区通用吐槽语是 "babysitting the agent"。

这个裂缝的结构值得看清：**终端赢在"agent 的行动效率"，输在"人的阅读效率"**。当模型生成速度越过人的 review 速度，界面的服务对象就该从 agent 换回人——但服务的不再是人的"写"，而是人的"读与判断"。

## 第四代：Codex App（2025-2026）——单位从 turn 变 task，界面为人的注意力重建

**修复方案**：sync → async，交互单位从"回合"升到"任务"。OpenAI Codex 的路径：2025.5 [云端 agent](https://openai.com/index/introducing-codex/)（沙箱、并行、PR 出口）→ 2025.9 [多 surface 收敛](https://openai.com/index/introducing-upgrades-to-codex/)→ 2026.2 [macOS 桌面 app](https://openai.com/index/introducing-the-codex-app/)，媒体定性为 "command center"。

我体验到的那个结构，是整个行业的收敛解——**三件套：左侧任务列表（并行 session）+ 中央对话/任务流 + 右侧可收起的 diff review 面板**。[Claude Code web](https://techcrunch.com/2025/10/20/anthropic-brings-claude-code-to-the-web/)（2025.10）与 [desktop](https://code.claude.com/docs/en/desktop-quickstart)、Cursor 2.0、Devin 2.0、Factory 全部长成这个形态。底座也同构：per-task 隔离（每个 agent 独立 worktree/VM）+ [review queue](https://codex.danielvaughan.com/2026/04/08/codex-desktop-automations/)（一处批量验收多个 agent 的产出）+ PR 作为出口工件。

为什么三件套是对的？它做的正是关注点分离，本质是**三种注意力模式各给一个专属区域**：

- **左侧 = 调度注意力**（我有哪些任务在飞、哪个要我了）——扫一眼的模式；
- **中央 = 理解注意力**（这个任务的意图、进展、agent 的说明）——沉浸阅读的模式，所以必须是稳定的对话流，不能被生成跳动打断，这正是 terminal REPL 给不了的；
- **右侧 = 验收注意力**（这次改动能不能过）——按需打开的模式，所以可收起。而且它是**任务 scoped 的 diff**，不是代码仓浏览器——review 的单位跟着任务走，不是跟着文件树走。

心流的来源就在这：三种模式不再互相打断。

**一个重要的反面案例**：Devin（2024.3）证明这个形态早了一年就是灾难——"first AI software engineer" 的异步云端 agent，[独立测试成功率约 15%](https://www.remio.ai/post/cognition-ai-built-a-coding-agent-with-a-15-success-rate-now-it-is-worth-25-billion)，人盯梢的成本高于自己写。方向对、模型没跟上，等于错。（而模型跟上后，Cognition 估值冲到 $25B。）这跟 ghost text 的例子首尾呼应，构成整个叙事最硬的一条定律：**交互形态既不能超前于模型能力（Devin 2024），也不能滞后于它（Cursor 2025）——它必须精确匹配当下的模型参数，而且保质期只有一个模型代际。**

---

## 底层结构：四次迁移其实是一张表

| 代际 | 稀缺的判断 | 界面围绕谁建 | 人的角色 | 交互单位 |
|---|---|---|---|---|
| Chat/补全 | 写什么代码 | 代码（编辑器缓冲区） | 作者 | 一次建议 |
| Cursor | 怎么改这批文件 | 代码 + 光标 | 作者 + 采纳者 | 一次编辑 |
| Claude Code | 批不批这个行动 | agent 的行动流 | 接线员 | 一个 turn |
| Codex app | 收不收这个任务 | 人的注意力 | 管理者 | 一个 task |

理论注脚是 Karpathy 2025.6 的 ["Software 3.0" 演讲](https://www.latent.space/p/s3)：AI 辅助工作的基本回路是 **generation-verification loop**，整体速度由验证速度决定（还有配套的 autonomy slider——应用应让用户拨"给 AI 多少自主权"的滑杆）。四代变迁可以一句话重述为：**generation 一路变快，verification 的形态就必须一路重构——从"读一行灰字"到"读一个 diff"到"批一个行动"到"验收一个任务"。** 界面每次重组，都是在为 verification 降本。

## 三条可以带走的洞察

**1. 本质需求从来没变过：让人的恒定注意力对准当前最稀缺的判断。** 变的只是稀缺判断的位置。所以判断"下一代工具长什么样"的方法不是看 UI 趋势，而是问：*当前这代模型参数下，人做的事情里哪一件最不该由人做？* 第一代是搬 context，第二代是手改多文件，第三代是接 turn。

**2. 主体换位决定界面语言。** 代码为主体 → 界面是编辑器；agent 为主体 → 界面是终端/对话；任务为主体 → 界面是任务管理器。第四代里对话没有消失，而是降维成了任务的**载体**——任务通过对话在流动，对话是 task 的容器，不再是交互的顶层单位。这也解释了 /goal 这类特性的位置：把"跨 turn 的任务"从对话里提出来，变成一等公民。

**3. 下一次迁移已经能看见了：瓶颈正在从 review 挪向信任的工程化。** 数据很刺眼：[AI 生成的 PR 等首个 reviewer 的时间长 4.6 倍](https://blog.codacy.com/ai-breaking-code-review-how-engineering-teams-survive-pr-bottleneck)；OpenAI 内部 [99 分位用户每天生成 60+ 小时的 agent 工作量](https://openai.com/index/how-agents-are-transforming-work/)，而 reviewer 吞吐还是那个老样子（几百行/小时）——人时和机时已经彻底解耦，人的验收吞吐成了硬上限。行业的回应方向是 "agent review agent，人做终审"（Codex 的 review queue、Cursor Bugbot、独立 review-agent 层）。但这只是把 review 队列压扁一层，真正的解要回答"人凭什么信"——也就是**验证的工程化：eval、合约、可机检的验收标准**。第五代工具的三件套里，右侧那块 diff 面板大概率会被"证据面板"取代：不是给你看改了什么，而是给你看凭什么可信。

这条线正好接回 [build-my-own-harness](https://github.com/maisieyang/build-my-own-harness) 里 dogfood → eval 的那套思考：dogfood 用眉头当 oracle 发现问题，eval 把眉头皱过的地方换成代码、永久保存。本质就是在给第五代的瓶颈备料。
