# 瓶颈在哪，交互重心就在哪：coding 工具四代变迁的一手记录

> 写于 2026-07-31，更新于 2026-08-05
> 起点是我自己的迁移史：ChatGPT → Cursor → Claude Code → Codex app，四次换工具，每次都不是因为"新工具功能多"，而是因为旧交互突然不顺了。这篇把这条体感主线补上调研事实，看清楚背后的规律。

## 引子：我的四次迁移

最早是 ChatGPT，chat 的形式，在浏览器和 IDE 之间来回搬代码。然后 Cursor 出来，觉得真好用——因为那个当下工作的起点是以代码为中心，Cursor 是很棒的 copilot。后来模型越来越强，我开始用 Claude Code 就不再用 Cursor 了：交互的重点转移了，agent 要写绝大部分的代码，**agent 是主体，不是代码**。terminal 天然适合多 session、多任务，作为程序员，在 terminal 里做这一切都很自然。

然后我发现它不顺了。模型生成代码的速度明显超出了我的注意力可以 review 的范围。terminal 的 REPL 让我的体感开始变差：我在阅读的时候它在生成，页面会跳，我滚回去，它又生成，又跳。我把 terminal 放大到屏幕 70% 的面积，阅读体验还是不好。我跟不上它的实现细节，但我还不能离开——我需要不停地接 turn，机械地接，大多数只是 approve。

深度体验了两天 Codex app 之后，我知道这就是我目前想要的：左侧是任务管理，中心最好的位置给任务的信息交互流，右侧是可收起的 diff review 面板。关注点在 task 时有完美的阅读体验；要 check 代码改动时打开右侧栏——不是代码仓浏览器，是**这一次任务的改动**。关注点分离做到了极致，这是一个能让人产生心流的工具。

四次迁移，四个当下，每个当下都有更适合的工具。这背后的规律是什么？

## 总命题

**每一代工具的形态，都不是设计品味的选择，而是对"当时模型参数下，人的注意力该花在哪"的精确适配。** 模型能力每上一个台阶，稀缺的判断就换一个位置，界面就围绕新的稀缺判断重组。

还有一条贯穿的暗线：**每一代的"暴露问题"都是上一代成功制造的**。copy-paste 的摩擦只有在 chat 真的有用之后才存在；review 瓶颈只有在 agent 真的高产之后才存在。瓶颈不消失，只迁移。

到第三、四代之间，还发生了一次容易被“CLI 对 GUI”的表面争论遮住的分工：

> **Terminal 释放的是 Agent 的能力；Task workspace 管理的是人的注意力。**

两者不是替代关系。Agent 仍然需要 shell、文件系统、Git、测试和进程这些接近 terminal 的
行动底座；人则需要稳定地调度任务、理解进展、审查变更和做最终验收。模型从 sync 走向
async 后，最好的 Agent execution surface 和最好的 human supervision surface 开始分离。

下面按"朴素方案 → 暴露问题 → 下一修复"的链条走四代。

---

## 第一代：Chat + Ghost Text（2021-2023）——人是 context 搬运工

**朴素方案**：模型给建议，人做一切其他事。两种形态：[GitHub Copilot](https://github.blog/news-insights/product-news/introducing-github-copilot-ai-pair-programmer/)（2021-06-29，官方定位 "AI pair programmer"，能力上限写明是"补全整行或整个函数"）的 ghost text，和 [ChatGPT](https://openai.com/index/chatgpt/)（2022-11-30）的 copy-paste 编程。

**为什么这是当时的合理解**——有个很锋利的数字：Copilot 底层的 Codex 模型 [HumanEval pass@1 只有 28.8%](https://arxiv.org/abs/2107.03374)。再叠加有限上下文和缺少行动通道，直接形成三重约束：

1. **上下文装不下工程现场**——模型看不到完整代码库，只能由人裁剪、搬运上下文。copy-paste 不是产品设计失误，而是系统边界的外显。
2. **单步能力撑不起长链条**——HumanEval 的单函数通过率不能直接换算成真实任务的多步成功率，但它足以说明：当时还不能把连续修改与验证交给模型独立完成。[Grounded Copilot](https://arxiv.org/pdf/2206.15000) 对 20 名开发者的研究也观察到，探索性使用者会检查代码、执行测试、做静态分析并查阅文档；有参与者直接把自己的角色描述为 code reviewer。
3. **没有行动通道**——没有工具调用、没有执行环境。

Ghost text 是对这三个参数的精确适配：建议不够可靠 → 把"拒绝"的成本压到零（继续打字即忽略），把"接受"压到一个 Tab。**低命中率 × 低成本拒绝，是这组模型参数下非常合适的交互。**

**暴露问题**：[GPT-4 Technical Report](https://cdn.openai.com/papers/gpt-4.pdf) 报告 HumanEval 0-shot 67.0% 后，建议变得更值得采用，人肉搬运 context 的摩擦开始上升。2023 年一场 [HN 讨论](https://news.ycombinator.com/item?id=36211250)里，Aider 作者 Paul Gauthier 给出的建议很直接："Don't copy-and-paste between a chat session and your files"。瓶颈位置：**把模型接到工程现场**。

## 第二代：Cursor（2023-2025）——把模型搬进代码的主场

**修复方案**：既然人不该做搬运工，就把模型嵌进 IDE，让它直接进入代码工作流。Cursor 在 2026 年回顾早期选择时写道，他们 [fork VS Code 而不是做扩展，是为了能够塑造自己的产品界面](https://cursor.com/blog/cursor-3)。这个决策在 2023 年很合理，因为**工作重心还在编辑器缓冲区里**：人仍是主要写码者，AI 的价值主要以贴着光标的交互（Tab、Cmd+K）交付。

**与模型跃迁的咬合**：2024-06-21 [Claude 3.5 Sonnet](https://www.anthropic.com/news/claude-3-5-sonnet) 发布；Anthropic 报告它在内部 agentic coding eval 中解决 64% 的任务。22 天后，Cursor 发布 [Composer beta](https://cursor.com/changelog/0-37-x)，把实验性的多文件编辑放进 IDE；2024-11-24 又上线了能自行选择 context、使用 terminal 的[早期 Agent](https://cursor.com/changelog/0-43-x)。模型开始能跨文件行动时，产品也从补全迅速转向编辑与执行。

**暴露问题**：agent 承担越来越多实现后，编辑器不再天然是全部工作的中心。2025 年一场 HN 讨论里，有迁移者把选择归因于 Claude 的编码能力，并说 "[the interface isn't meaningful](https://news.ycombinator.com/item?id=45789738)"。Cursor 自己的产品变化更能说明问题：2025-08-07 发布 [CLI beta](https://forum.cursor.com/t/cursor-cli-beta-available-now/126964/)，2025-10-29 又在 [Cursor 2.0](https://cursor.com/blog/2-0) 中推出最多八个并行 Agent、worktree 隔离和集中 diff review。编辑器没有消失，但主界面开始为 Agent 协调重新分配空间。

Michael Truell 在 [Lenny's Podcast](https://www.lennysnewsletter.com/p/the-rise-of-cursor-michael-truell) 里把方向描述为 "what comes after code"：编程会更多转向自然语言或伪代码，但专业开发者仍需要精确控制。这个判断解释了 Cursor 在 Agent 化的同时为何保留代码与 diff——也预告了第四代里 review 面板的位置。

## 第三代：Claude Code（2025）——agent 为主体，终端是它的自然居所

**修复方案**：既然主体换位了，就把界面从"人的写码环境"换成"agent 的行动环境"。前驱 [Aider](https://aider.chat/) 至少在 2023 年 6 月就以 "AI pair programming in your terminal" 为定位，并把 [Git 纳入工作流](https://aider.chat/docs/git.html)。2025-02-24，[Claude Code](https://www.anthropic.com/news/claude-3-7-sonnet) 在 limited research preview 中更明确地把 terminal 变成委托工程任务的入口：它可以搜索和读取代码、编辑文件、运行测试并操作 Git。

Boris Cherny 的设计哲学原话（[Latent Space 播客](https://www.latent.space/p/claude-code)）："It's **raw access to the model**... we literally could not build anything more minimal"、"we think of it as a **Unix utility**"。这套取舍让强模型的能力以更少产品层包装直接暴露，也保留了与其他工具组合的空间。

终端形态天然支持**可组合**：管道、`-p` headless、CI 与脚本化；配合 terminal multiplexer 和 Git worktree，又能低成本扩展到并行 session。行业在四个月内连续出现同类入口：Claude Code（2025-02）→ [OpenAI Codex CLI（2025-04）](https://openai.com/index/introducing-upgrades-to-codex/) → [Gemini CLI（2025-06-25）](https://blog.google/innovation-and-ai/technology/developers-tools/introducing-gemini-cli-open-source-ai-agent/)。

但这里的“并行”首先是执行能力：程序员可以打开更多 terminal，让更多 Agent 同时行动。

**暴露问题**——我的体感有两层，也都能找到外部证据：

- **物理层**：终端滚动跳动、流式输出覆盖手动回滚、阅读被生成打断。Claude Code 官方 repo 中一个 [2026-03-16 创建的 issue](https://github.com/anthropics/claude-code/issues/34845) 精确记录了这两种现象：随机跳回顶部，以及生成期间自动滚动覆盖用户手动回看。
- **认知层**：GitLab 在 2026 年 6 月发布的一项[覆盖六国 1,528 名开发者与技术采购者的调查](https://about.gitlab.com/press/releases/2026-06-23-gitlab-research-reveals-organizations-are-generating-ai-code-faster-than-they-can-control-it/)中，85% 的受访者同意 AI 已把瓶颈从写代码移到 review 与 validation。Addy Osmani 的表述几乎和体感逐字一致："[The bottleneck is no longer how fast you write code, it is how fast a trusted human can be confident in a review](https://addyosmani.com/blog/agentic-code-review/)"。同步 REPL 把人绑在 turn-taking 上，而其中很多 turn 只是确认继续。

这个裂缝的结构值得看清：**终端赢在"agent 的行动效率"，输在"人的阅读效率"**。当模型生成速度越过人的 review 速度，界面的服务对象就该从 agent 换回人——但服务的不再是人的"写"，而是人的"读与判断"。

## 第四代：Codex App（2025-2026）——执行仍在终端，界面转向人的 read 与 review

**修复方案**：不是把 Agent 从 terminal 迁走，而是在保留 shell、代码库、测试与 Git 这套 Agent 行动环境的同时，为人补上一层以 task 为中心的 read/review 界面。OpenAI Codex 的路径：2025-05-16 [云端 agent](https://openai.com/index/introducing-codex/)（沙箱、并行、PR 出口）→ 2025-09-15 [多 surface 收敛](https://openai.com/index/introducing-upgrades-to-codex/)→ 2026-02-02 [macOS 桌面 app](https://openai.com/index/introducing-the-codex-app/)。官方现在把桌面形态描述为支持 [parallel project chats、内建 Git review 与 worktrees](https://learn.chatgpt.com/docs/whats-new#the-codex-app-launches-on-macos) 的工作区。

我体验到的关键结构是：**左侧任务列表（并行 session）+ 中央对话/任务流 + 右侧可收起的 diff review 面板**。其他 agent 产品也在向并行 session、隔离执行和集中 review 靠拢；这里重要的不是“三栏布局”本身，而是 execution plane 与 human control plane 开始分离：Agent 仍以命令和工具调用推进工作，人却不必再从持续滚动的 terminal session 中重建发生了什么，而是围绕一个个 task 阅读过程、检查 diff 并验收结果。**Agent 的行动单位仍可以是 command 和 turn，人的监督单位才从 turn 上升为 task。**

为什么三件套是对的？它做的正是关注点分离，本质是**三种注意力模式各给一个专属区域**：

- **左侧 = 调度注意力**（我有哪些任务在飞、哪个要我了）——扫一眼的模式；
- **中央 = 理解注意力**（这个任务的意图、进展、agent 的说明）——沉浸阅读的模式，所以必须是稳定的对话流，不能被生成跳动打断，这正是 terminal REPL 给不了的；
- **右侧 = 验收注意力**（这次改动能不能过）——按需打开的模式，所以可收起。而且它是**任务 scoped 的 diff**，不是代码仓浏览器——review 的单位跟着任务走，不是跟着文件树走。

心流的来源就在这：三种模式不再互相打断。

---

## 底层结构：四次迁移其实是一张表

| 代际 | 稀缺的判断 | 界面围绕谁建 | 人的角色 | 交互单位 |
|---|---|---|---|---|
| Chat/补全 | 写什么代码 | 代码（编辑器缓冲区） | 作者 | 一次建议 |
| Cursor | 怎么改这批文件 | 代码 + 光标 | 作者 + 采纳者 | 一次编辑 |
| Claude Code | 批不批这个行动 | agent 的行动流 | 同步监督者 | 一个 turn |
| Codex app | 先处理、验收哪个任务 | 人的注意力 | 调度者 + 验收者 | 一个 task |

## 三条可以带走的洞察

**1. 本质需求从来没变过：让人的恒定注意力对准当前最稀缺的判断。** 变的只是稀缺判断的位置。所以判断"下一代工具长什么样"的方法不是看 UI 趋势，而是问：*当前这代模型参数下，人做的事情里哪一件最不该由人做？* 第一代是搬 context，第二代是手改多文件，第三代是接 turn。

**2. 主体换位决定界面语言。** 代码为主体 → 界面是编辑器；agent 行动为主体 → 界面是终端/对话；人的 read/review 为主体 → 控制界面围绕任务组织。第四代没有替换 Agent 的终端行动面，而是在它上面增加了 task management；对话也没有消失，而是成为 task 的过程记录，不再是人组织工作的顶层单位。这也解释了 Plan / Default / Goal 的位置：它们不是三个零散功能，而是在 task 生命周期中选择人、模型与 harness 如何分配控制权。

**3. 下一次迁移已经能看见了：瓶颈正在从 review 挪向信任的工程化。** LinearB 的 2026 benchmark 基于 8.1M+ 个 PR，报告 [AI PR 等待 review 的时间是普通 PR 的 4.6 倍](https://linearb.io/resources/software-engineering-benchmarks-report)；OpenAI 则报告，2026 年 6 月其内部日活用户的 99 分位已经能在一天内产生 [60+ 小时、分布在多个并行 Agent 上的 Codex agent turns](https://openai.com/index/how-agents-are-transforming-work/)。两组口径不同，却共同说明人时和机时正在解耦，人的验收吞吐会成为硬上限。行业开始让 Agent 参与 review，但这只是把 review 队列压扁一层，真正的解要回答"人凭什么信"——也就是**验证的工程化：eval、合约、可机检的验收标准**。第五代工具的三件套里，右侧那块 diff 面板大概率会被"证据面板"取代：不是只给你看改了什么，而是给你看凭什么可信。

我现在更愿意把这条演进压成两句话：

> Terminal-first 让 Agent 充分行动；task-first 为人组织阅读、调度与验收。
>
> 当人的主要工作从写代码、接 turn 转向 read/review，Harness 必须在 Agent 的 execution plane 之上建立 task control plane。
