# 拆解 Anthropic 的产品逻辑

## 1. 先看历史：Claude Code 是长出来的，不是规划出来的

Anthropic 现在的产品逻辑看起来 clean —— 统一 harness、行业 plugin、按需加载 skill —— 但要真的理解它为什么 work，得先回到 2024 年看看这套体系是怎么发生的。

Anthropic 2021 年 1 月由 7 个 OpenAI 出来的人创办，由 Dario 和 Daniela Amodei 领头。2023 年 3 月 14 日发布第一个公开产品 —— Anthropic API + Claude 和 Claude Instant。注意是 API，不是 chatbot。从这一天到 2024 年底，**Anthropic 商业模式高度集中：70-75% 收入来自 pay-per-token 的 API 调用**，剩下来自 Claude Pro / Team / Enterprise 订阅。

跟 OpenAI 完全相反 —— OpenAI 走的是消费级 chatbot（ChatGPT），9 亿周活；Anthropic 不去争消费入口，从 2023 年起一直押企业 API 合同 + 开发者 adoption。**他们是一家 API 公司**。这一点至关重要 —— Claude Code 不是从 day-1 战略蓝图里规划出来的。

2024 年 9 月，Boris Cherny 加入 Anthropic 做 founding engineer。他之前在 Meta 干了 5 年 principal engineer，做过 Instagram 代码库现代化。Anthropic 没有给他"去做编程产品"的 mandate，他只是新员工在探索 API。

转折点是几个月后他的 manager Ben Mann（Anthropic co-founder 之一）给的一句 north star。这句话后来在所有讲 Claude Code 起源的访谈里被反复引用：

> **"Don't build for today's model. Build for the model in six months."**

这段历史最关键的不是 Boris 写了多少行代码，是**模型版本的发布节点跟 Claude Code 能力曲线的直接绑定**。这件事值得单独画一张时间轴出来看：

```
2024-09  ┃ Boris 入职。底层模型 = Claude 3.5。
         ┃ Boris 拿 Claude 3.5 prototype CLI 工具。
         ┃ 能用，但 Boris 自己只用它写 10% 代码。
         ┃
2024-10  ┃ Claude 3.6 ship。能力小幅提升，prototype 仍勉强可用。
         ┃
         ┃    ──── 前 6 个月："barely usable" 阶段 ────
         ┃
2025-02  ┃ Claude Code 以 research preview 形态首次公开。
         ┃
2025-05  ┃ ★ Claude Opus 4 ship。
         ┃ 同一个 harness、同一个 prototype，突然真的可用。
         ┃ Boris 把它 share 进 Anthropic 内部。
         ┃ 内部工程师立刻 organic 上手 —— 没有 OKR、没有 launch event。
         ┃ ★ Claude Code 同月 GA。
         ┃
2025-11  ┃ ★ Claude Opus 4.5 ship。
         ┃ 第二次能力跃升。这次裂变出 Anthropic 外。
         ┃ Pragmatic Engineer 15K 开发者 survey: Claude Code 46% "most loved"。
         ┃ Boris 自己从这个月开始完全不再用手写代码。
         ┃
2026-初   ┃ Claude Code 单产品 $2.5B 年化收入。
         ┃ 2M+ 周活。4% 公开 GitHub commits。
```

这张图里**模型版本的发布是因果链的发动机**：

- **Opus 4 之前**：harness 设计可能已经差不多就位了，但产品没有飞。Boris 自己用 10%。这一阶段如果 Anthropic 发力做 marketing，效果约等于 0 —— 模型不够强，用户用一次就走。
- **Opus 4 ship 那一刻**：同样的 harness 没改，但底层模型够强了。产品瞬间从 "barely usable" 变成 "我宁愿用它写代码"。**裂变第一波发生在 Anthropic 内部**，3 个月里 80%+ 工程师开始每天用。
- **Opus 4.5 ship 那一刻**：能力再次跃升，裂变扩散到外部技术社区。Pragmatic Engineer 2026 年 2 月那次 15K 开发者 survey 的 "most loved" 46% 是这个时间点之后的事。

**这条因果链反过来印证 Ben Mann 那句 "为 6 个月后的模型做" 是对的**。Boris 在模型还做不到的时候提前把 harness 准备好，模型升一代他不用改 harness 就直接吃到全部 capability boost。如果他当初按 Claude 3.5 的能力上限设计 harness（比如塞一堆 multi-agent 编排、prompt 工程兜底），Opus 4 ship 那一刻他就要全部重写 —— 而重写期间 Anthropic 内部根本来不及 viral。

**Claude Code 这个产品的成功本质上是模型能力曲线和 harness 设计的耦合输出**。把它说成 "Anthropic 押对了模型会变强" 在结果上没错，但把这事讲成 "Anthropic 当年规划好了" 是事后归因。真正发生的事是：底层模型在 2025 年 5 月和 2025 年 11 月两次跃升，正好撞上一个为强模型准备好的 harness。**两件事独立发生，又恰好对上**。

完全没有 Anthropic 启动消费 chatbot 那种 hype。Claude Code 是 dogfood 出来的 + 模型升级带飞出来的 + 自然传播出来的。到 2026 年初，单 Claude Code 这个产品的年化收入做到 $2.5B。

我把这段历史摆在前面，是因为今天 Anthropic 官方叙事里 "all products bet on model getting stronger" 这条 thesis，**不是 2021 年 day-1 拍出来的蓝图**。它是事后证实的判断 —— Boris 的实验 + Ben Mann 的 north star + Opus 4 的能力突破，三件事叠在一起 retrospectively 验证了它。

这个区分重要。**如果你以为 Anthropic 从 day-1 就知道 harness 应该薄、应该做行业 plugin —— 你会以为这是 visionary 团队的 strategic foresight**。实际更接近 "在 API-first 路线上，一个新员工因为一句对的话，做了一个跟模型协同进化的 prototype，碰到模型真的变强了，飞起来了"。

天时（Opus 4 ship 让 harness 上的 workaround 都不再需要）、地利（Anthropic 本来就是 API 公司，给了 Boris 探索的 surface）、人和（Boris + Ben Mann 各自做对了一件事）—— **三个条件缺一个都跑不出来今天这个产品矩阵**。

理解了这一点，回头看现在的 thesis 才能落地：**Anthropic 的产品逻辑不是"我们押对了"，是"我们押的事 happen to be 对，而且我们识别得早，把整个公司的下一步规划压到这条路上"**。这两个表述工程含义完全不同 —— 前者是天才战略家的故事，后者是 founding engineer 实验 + 高 conviction 快速 follow-through 的故事。第二个版本更接近现实，也更可复制。

## 2. 现在的根命题：模型会持续变强，所以底座要薄

Anthropic 现在复盘出来的 product principle 是：**如果模型会持续变强，今天为了弥补模型能力不足而叠加的大量工程复杂度，未来都会变成负担**。

复杂的 multi-agent 编排框架 —— 模型变强后单个 agent 就能做。精巧的 output parser —— 模型变强后自己就能输出结构化数据。大量的 prompt engineering 技巧 —— 模型变强后自己理解任务意图。

反过来推 —— 如果你押模型会变强，产品形态就应该是"极简底座 + 可扩展能力"。底座保持极简，让模型的进步直接转化为产品能力的提升；能力的扩展通过松耦合的插件而不是硬编码进框架。

从这个根命题往下走一步 —— agent 在 Anthropic 的产品体系里就有一个清晰的定义：

**Agent = Model + Harness**

Model 提供智能（reasoning、language understanding、tool use 能力），Harness 提供让智能能落地工作的外部 scaffolding —— 工具调用、上下文管理、状态、权限、审计。

更关键的是 —— 这个 Harness 在 Anthropic 的产品里是统一的、共享的、不为每个 vertical 重做的。

这意味着 Anthropic 不是 "做了 N 个 agent 产品"，是 "做了 1 个 Harness，让它能加载 N 套行业配置"。这两种说法听起来差不多，经济和工程含义完全不同 —— 前者是 N 倍工程投入和 N 倍维护，后者是 1 倍工程投入加上配置可以由生态甚至客户自己写。

这是 Anthropic 的小工程团队能服务 1000+ 个 $1M+ 客户的根本原因。所有的 leverage 都集中在 "1 个 Harness" 这件事的设计上 —— 但要记住，**这个 leverage 在 2024 年还没显现，是 Boris + Opus 4 + 12 个月 iteration 之后才长出来的**。

---

## 3. 先澄清一个术语：关于Harness 的定义
在进入探讨之前，必须先把 "Harness" 这个词说清楚——整个 AI agent 行业都在做 Harness，但这个词在不同上下文里指的不是同一个东西。
Harness 在 Anthropic 自己的产品讨论和行业的公开讨论里，实际上有两种使用方式：
### 3.1 狭义 Harness：Agent Runtime
这是 “Model + Harness = Agent” 这个等式里的 Harness。
它指的是让模型能够作为智能体持续工作的那一套核心运行机制，包括：agent loop、tool use、conversation state、subagent dispatch、permission system、context management、audit trail。
这一层不是用户看到的界面，而是模型旁边那层“让模型能把事情做完”的运行时。你可以把它理解成智能体的操作系统内核。
### 3.2 广义 Harness：Agent Runtime + 产品接触面
在日常讨论 Claude Code、Claude for Enterprise、桌面端产品、浏览器扩展时，大家说的 Harness 往往更宽。
它不仅包括运行时，还包括用户接触智能体的方式：命令行、编辑器插件、聊天界面、办公软件插件、浏览器扩展、桌面端应用，以及企业部署和授权方式。

这两种含义不是矛盾关系，而是嵌套关系。狭义 Harness 是核心运行时，广义 Harness 是运行时加上产品接触面。
```
广义 Harness（完整产品体验）
├── 用户接触面 / Surface（CLI、Chat UI、Office add-in、Chrome extension）
├── 交付层（marketplace、安装、licensing）
└── 狭义 Harness（Agent Runtime）── 本文之后简称 "Harness"
    ├── Agent loop
    ├── Tool use
    ├── Conversation state
    ├── Skill / MCP 加载
    └── ...
```

本文后面统一使用一个约定：Harness 指狭义的智能体运行时；产品接触面指用户实际使用 Claude 的入口。
这个区分很重要。因为做产品判断时，如果把运行时和界面混在一起，就很容易误判 Anthropic 真正的设计重心。Anthropic 真正在押的，不是某一个聊天界面、某一个命令行工具，而是底层 Harness 能不能成为所有工作场景的共同运行时。

---
## 4. Anthropic 的产品矩阵：不是多个产品，而是一套分层系统
把 Anthropic 已经发布或正在推进的产品放在一起看，会发现它不是横向堆很多产品，而是一个非常清楚的分层系统。
### 4.1 行业场景：从代码进入高价值知识工作
过去一年多，Anthropic 进入的行业场景大致包括：
| 行业 | 行业能力包 / 产品 | 典型任务形态 |
|---|---|---|
| 软件开发 | Claude Code | 读代码、改代码、测试、重构 |
| 金融服务 | Claude for Financial Services | 估值模型、研报、IC memo、KYC |
| 法律 | Claude for Legal | 合同起草与审阅、诉讼支持 |
| 生命科学 | Claude for Life Sciences | 试验方案起草、文献综述 |
| 医疗健康 | Claude for Healthcare | 临床文档、病历起草 |
| 私募 / Deal-making | PE bundle | 尽调、deal memo |
| 网络安全 | Security | 告警分析、安全审计 |

这些行业看起来差异很大，但底层结构很像：它们都是高价值知识工作，都依赖大量文档、数据和流程，也都需要“AI 起草，人类审核”的协作方式。
### 4.2 技术分层：统一底座，上层加载行业能力
如果从技术层看，Anthropic 的产品矩阵可以拆成四层：
```
┌──────────────────────────────────────────────────────┐
│ Layer 4: Plugin（行业 Agent）                          │
│ KYC Screener · Statement Auditor · Litigation         │
│ Associate · Trial Protocol Drafter · IC Memo ...      │
├──────────────────────────────────────────────────────┤
│ Layer 3: Vertical Bundle（行业能力包）                  │
│ Financial Services · Legal · Life Sciences ·          │
│ Healthcare · PE / Deal-making                         │
├──────────────────────────────────────────────────────┤
│ Layer 2: Surface（产品接触面）                          │
│ Claude Code · Cowork · M365 Add-in ·                  │
│ Chrome Extension · Desktop · Managed Agents API       │
├──────────────────────────────────────────────────────┤
│ Layer 1: Model + Harness（统一底座）                    │
│ Claude Opus 4.7 + Agent Runtime + MCP + Skills        │
└──────────────────────────────────────────────────────┘
```
关于这个图的每一层：
- Layer 1（Model + Harness，统一底座）：所有产品共享的底层——Model 提供智能，Harness 提供让 model 能持续工作的核心机制（工具调用、上下文管理、状态、权限、审计）
- Layer 2（Surface，产品接触面）：统一底座触达用户的产品形态——Claude Code（CLI / IDE）、Cowork（chat 界面）、Office add-in、Chrome 扩展、Desktop、Managed Agents API
- Layer 3（Vertical Bundle，行业能力包）：每个 vertical 一套的 skill bundle + connector 配置——金融、法律、生命科学、医疗、PE / Deal-making 等
- Layer 4（Plugin，行业 Agent）：vertical 内部的具体 named agent——KYC Screener、Statement Auditor、Litigation Associate、Trial Protocol Drafter 等
以金融 行业 为例，Layer 3 和 Layer 4 的关系长这样：
- Layer 3：金融 vertical 内部拆成 4 个 sub-bundle，对应 4 个细分业务——Investment Banking、Equity Research、Private Equity、Wealth Management。每个 sub-bundle 包含该业务的核心 skill（DCF、comps、IC memo 等）+ connector（Bloomberg、FactSet、S&P 等）+ slash command（/comps、/dcf、/ic-memo）
- Layer 4：金融 vertical 提供 10 个 named agent——Pitch Builder、KYC Screener、GL Reconciler、Statement Auditor、Month-end Closer、Earnings Reviewer、Model Builder、Market Researcher、Valuation Reviewer、Meeting Preparer。每个 agent 对应一项具体任务
两层是上下关系——Layer 4 的 agent 在工作时，复用 Layer 3 的 skill 和 connector。比如 Pitch Builder 在做 pitch book 时，调用 Investment Banking sub-bundle 里的 DCF skill 和 Bloomberg connector。Bundle 像"工种工具箱"，Plugin 像"工具箱里完成具体一项活的入口"。
换句话说——Layer 1 是 "agent 本身"，Layer 2 是 "agent 怎么到达用户"，Layer 3 + 4 是 "agent 怎么变成行业专家"。三件事在 Anthropic 的产品矩阵里清晰分层、相互正交。
因此，Anthropic 的行业扩张不是“每个行业重做一个产品”，而是：
统一 Harness + 不同行业能力包 + 不同产品接触面。
这就是它能够快速横向扩张的关键。每进入一个新行业，真正增加的是第三层和第四层，第一层和第二层保持相对稳定。

---
## 5. Harness 的三个基础构件：MCP、Plugin、Skill
底座要保持极简，但能力又要扩展到很多行业。这个矛盾怎么解决？
Anthropic 的答案不是做一个巨大的框架，而是抽象出三个基础构件：MCP、Plugin 和 Skill。
### 5.1 MCP：解决“怎么连接外部世界”
MCP，全称 Model Context Protocol，可以理解为模型与外部数据源、工具和系统之间的标准连接协议。
它解决的是一个典型的多对多集成问题。没有标准协议时，N 个智能体产品要连接 M 个外部系统，就需要 N × M 次集成。每个模型厂商、每个应用、每个数据源都要重复适配。
有了 MCP 后，智能体产品只要实现 MCP 客户端，外部系统只要实现 MCP 服务端，就能通过同一套协议连接起来。集成复杂度从 N × M 降到 N + M。
这就是为什么 Anthropic 没有把 MCP 做成私有 SDK，而是做成开放协议。协议的意义不是“我多一个开发工具”，而是“我把连接世界这件事标准化”。
更深一层，开放协议也是一种生态承诺。Anthropic 把工具集成这件事交给生态，生态做的连接器越多，Claude 能使用的外部能力就越多。因为 MCP 不把生态强行锁死在 Claude 上，反而降低了生态投入的风险。

### 5.2 Plugin：解决“加载什么能力”
Plugin 是按需加载的能力单元，是 Anthropic 在行业扩展上的关键构件。
具体形态：
```bash
claude plugin install kyc-screener@claude-for-financial-services
claude plugin install litigation-associate@claude-for-legal
claude plugin install trial-protocol-drafter@claude-for-life-sciences
```
每个 plugin 是独立的可寻址单元，有四个关键属性：
1. 按需加载：用户不需要的 plugin 不进 context，不消耗 token，不增加模型困惑
2. 版本可控：plugin 可以独立升级、回滚——不会因为升级某个 vertical 影响其他 vertical
3. 权限可控：每个 plugin 有独立的 connector 授权、tool permission、audit log——合规边界清晰
4. 独立 release：plugin 可以分阶段发布给不同客户群体，不需要整个产品 ship-or-skip
最关键的——plugin 边界 = 组织边界。合规部门可以认领 KYC Screener、风控部门可以认领 Statement Auditor、法务部门可以认领 Litigation Associate。从组织视角看是 N 个"数字员工"，从工程视角看只是同一个 Harness 加载不同的 plugin bundle。
这套设计同时满足了两个看起来矛盾的需求：组织需要的"清晰责任边界" + 工程需要的"统一底座"。
### 5.3 Skill：解决“沉淀什么经验”
如果说 MCP 连接外部系统，插件组织能力边界，那么 Skill 解决的是一个更关键的问题：行业经验如何沉淀下来，让模型可以稳定复用。
在 Anthropic 的设计里，Skill 通常以 Markdown 文档为核心，用来描述某类任务的流程、规范、判断标准、示例和工具使用方式。
为什么是 Markdown？
- 第一，模型天然理解 Markdown。模型的训练数据、系统提示词、文档语料和输出格式，大量都是 Markdown。用 Markdown 写 Skill，相当于用模型最熟悉的语言描述能力。
- 第二，业务专家可以直接参与。律师、医生、银行分析师、研究人员都可以阅读和修改 Markdown，而不必先成为工程师。这一点对行业扩张非常关键，因为真正理解领域工作流的人，往往不是写代码的人。
- 第三，它支持渐进式加载。核心说明可以进入上下文，详细参考、示例、脚本和模板只在需要时加载。这样既能让模型知道某个技能存在，又不会一开始就把所有内容塞进上下文窗口。
Skill 的意义在于，它把原本存在于专家脑中的隐性经验，变成了可以版本化、可审阅、可分享、可执行的显性资产。
这也是 Anthropic 的 Harness 设计中最容易被低估的一点：它不是只在做“工具调用”，而是在为行业知识找到一种能被模型直接消费的载体。
### 5.4 三个构件合在一起
把 MCP、插件和 Skill 合在一起看，Anthropic 的扩展机制就很清楚了：
- MCP 负责连接外部世界；
- 插件负责组织和加载能力；
- Skill 负责沉淀行业经验。
一个行业产品，本质上就是一组插件；每个插件包含若干技能和连接器配置；它们共同运行在同一个 Harness 上。
所以 Anthropic 的行业扩张不是不断重写产品，而是不断把新的行业知识、工具连接和任务入口加载到同一个运行时里。

---
## 6. Anthropic 的四个核心押注
理解了产品矩阵和技术底座之后，下一步是看清这套布局背后的 战略意图——为什么这么布局，押的是什么。
我看到四个战略意图，每一个都比表面上看起来更深。
### 6.1 Claude Code 不仅是开发者工具，更是后训练飞轮
很多人会把 Claude Code 理解成 Anthropic 的开发者产品。这个理解没有错，但还不够深。
在 Anthropic 的战略里，编程不是普通的垂直行业，而是一个“元行业”。它不只是收入来源，更是模型后训练飞轮的入口。
编程任务有几个其他行业很难同时具备的特征。
1. 结果可验证：代码能不能编译，测试能不能通过，功能有没有实现，都能形成相对明确的反馈信号。
2. 数据量大。开发者每天会产生大量真实任务：读代码、改代码、写测试、修复错误、重构模块、解释系统行为。这些都是高质量的智能体轨迹。
3. 任务复杂度连续分布。从修改一行代码到完成一次大规模重构，任务复杂度可以自然分布。
4. 正反馈快：模型变强 → Claude Code 体验变好 → 更多开发者用 → 更多数据 → 模型更强
这是 RLHF 时代之后最重要的训练数据闭环。GPT-4 那一代主要靠人类标注，Claude Opus 4.7 这一代很大程度上靠 Claude Code 跑出来的 agent trajectory。
更深的一层——Claude Code 不只是给 Anthropic 提供 training data。它间接提供了 RLAIF 数据：开发者拒绝/接受 Claude 的 PR、修改/不修改 Claude 写的代码、测试 pass/fail——这些都是 scalable preference signal，比人类标注便宜 100 倍，比纯 RL 信号准 10 倍。
所以 Claude Code 不是 toD 产品，是 toD 包装的 training infrastructure。
这是 PM 视角的关键 reframe。从外部看 Claude Code 是给开发者用的工具；从 Anthropic 内部产品决策视角看，它的首要战略意义是验证根命题（模型会变强）的飞轮，其次才是产品收入。这两个目标都达到了——它既贡献 50%+ 的企业收入，又持续产生下一代模型的训练数据。
### 6.2 行业选择不是随机的，而是围绕高价值工作流展开
Anthropic 进入行业的顺序并不是随机的。
除了代码之外，它选择的行业高度一致：生命科学、医疗健康、法律、金融服务、私募交易、网络安全。这些行业都有三个共同特征。
1. 高合规：把别人不敢碰的地方变成优势
高合规行业通常是 AI 产品最难进入的地方。医疗有隐私和合规要求，金融有监管和审计要求，法律有责任边界和专业规范。
但对 Anthropic 来说，这些高门槛反而是机会。它一直把自己定位成重视安全、可靠性和企业可信度的 AI 公司。这个品牌心智天然适合进入高合规行业。
高合规不是扩张阻力，而是 Anthropic 区分自己的方式。
2. 高客单价：优先进入高价值知识工作
这些行业里的专业人士，本身就是高价值知识工作者：律师、医生、投行分析师、研究人员、合规专家、审计人员。
他们的时间昂贵，工作成果高价值，且很多任务高度依赖文档、分析和判断。因此，只要 AI 能真正提升效率，就有足够的商业空间支撑企业采购。
这和低客单价、高流量的消费级场景完全不同。Anthropic 明显更愿意先吃企业高价值工作流，而不是去争夺娱乐、社交、电商这样的消费入口。
3. 工作流可拆解：天然适合“AI 起草，人类审核”
这些行业还有一个共同点：工作流普遍可以拆解成“起草、审核、确认”。
律师起草合同，合伙人审核，客户确认。医生生成病历草稿，主治医生审核，进入正式病历。分析师做估值模型，董事总经理审核，再发给客户。
这正好匹配 Anthropic 的产品哲学：AI 先完成草稿和分析，人类保留审核、判断和责任。
这不是完全自动化，而是把 AI 放在最适合的位置：承担大量信息处理和初稿生成，把最终判断留给人。

反过来看，Anthropic 没有优先进入的行业，同样值得注意。
- 没进消费者社交、娱乐、电商——这些是 OpenAI 的战场，让出
- 没进政府、国防——美国政府 GovCloud 是 Anthropic 在 Microsoft 体系下吃的，不需要单独 vertical
- 没进教育——监管和商业模式不清，先放着

所以，Anthropic 的行业选择并不是“哪里有需求就去哪里”，而是非常克制地选择了一组更符合自身优势的场景：
高合规、高客单价、工作流可拆解，并且天然需要“AI 起草，人类审核”。
这种克制很重要。产品战略不只是选择做什么，也包括选择暂时不做什么。Anthropic 的产品组合之所以显得清晰，是因为它没有被“所有行业都可以做 AI”这个诱惑牵着走，而是始终围绕同一套进入标准展开。
### 6.3 分发策略：把 Claude 放进用户已经工作的地方
Anthropic 的另一个重要判断是：不要强迫企业用户迁移到一个全新的工作空间，而是把 Claude 放进他们已经工作的地方。
这就是为什么办公软件插件、浏览器扩展、桌面端、聊天界面、命令行和编辑器集成同样重要。
开发者已经在终端和编辑器里工作，所以 Claude Code 进入终端和编辑器。
白领已经在文档、表格、邮件和浏览器里工作，所以 Claude 要进入办公软件和浏览器。
企业员工已经在各种内部系统和 SaaS 里工作，所以 Claude 需要通过连接器和扩展进入这些系统。
这背后的战略意义是降低采购和使用阻力。
传统企业软件进入大公司，往往要经历漫长的采购、审查、试点和推广流程。但如果 Claude 以插件或扩展的方式进入已有工作环境，它就不再像一个“全新系统”，而更像已有系统里的新增能力。
这不是一个小的交互优化，而是分发策略。
Anthropic 不是试图让所有人先打开一个新的 Claude 应用，再把工作搬进去；它是在反过来做：让 Claude 出现在用户每天已经打开的地方。

### 6.4 从幕后能力到前台入口：Claude 想成为知识工作的操作系统
理解 Anthropic 的最终野心，需要看清一个变化：Claude 不想只做其他软件背后的模型能力，它想成为用户完成工作的前台入口。
过去，很多垂直 AI 应用会把 Claude 当成后端模型。用户打开的是法律 AI、金融 AI、科研 AI 产品，Claude 在背后提供推理和生成能力。
但当 Anthropic 开始自己发布法律、金融、医疗、生命科学能力包时，它的位置就变了。
它不再只是别人产品背后的模型供应商，而是在直接进入应用层。
这意味着价值链可能发生变化。
以前的结构是：
用户 → 垂直 SaaS 或垂直 AI 应用 → Claude 模型 → 数据源
Anthropic 想推动的结构是：
用户 → Claude 产品接触面 → Claude Harness → 数据源与企业系统
在这个结构里，传统 SaaS 和数据平台不一定消失，但它们可能退到连接器和数据源的位置。用户不再主要通过它们的界面完成工作，而是通过 Claude 这个智能入口调动它们。
想象一个金融分析师早上开始工作。
她不一定先打开 Bloomberg、Excel 和 Outlook，而是先打开 Claude。她说：帮我跟踪今天某家公司的业绩会，对比卖方预期，找出最值得追问的三个问题。
Claude 调用市场数据连接器、公司内部研究库、历史报告和邮件上下文，生成分析结果。分析师审核后，让 Claude 起草客户简报，再进入 Word 做最终编辑，通过邮件发出。
在这个流程里，传统软件还在，但它们的位置变了。Bloomberg 和 FactSet 变成数据连接器，Word 变成最终编辑器，Outlook 变成交付渠道。真正承载“理解任务、组织信息、形成判断”的中间层，被 Claude 接走了。
这就是 Anthropic 最激进的地方：它不是只想做模型层，而是想把模型层和应用层连接起来，成为知识工作的默认入口。
## 7. 把扩展权交给企业：Anthropic 如何覆盖长尾场景
Anthropic 不可能亲自做完所有行业。
金融、法律、医疗、生命科学只是参考样板。真正的长尾在企业内部：保险、制造、能源、零售、物流、教育、政企、内部运营、IT 支持、人力资源、财务共享、风控合规。
这些场景太多、太细、太依赖企业内部系统，不可能全部由 Anthropic 官方定义。
所以 Anthropic 需要提供企业自定义能力：Anthropic 还提供 Claude Agent SDK 和 Managed Agents API，让企业能自己定义 agent。。
这层能力的战略意义是：Anthropic 不需要自己知道每个行业、每家公司、每个部门应该怎么工作。它只需要提供通用 Harness 和扩展机制，让企业自己把内部工作流接进来。
官方行业包是样板，企业自定义是规模化的真正来源。
当这件事跑通后，Anthropic 的产品矩阵就不只是它自己发布过的产品，而是整个企业生态在它的 Harness 上构建出的所有能力。


---
## 8. 从模型进步到行业扩张：Anthropic 的产品路径
到这里，Anthropic 的产品逻辑已经可以串成一条清晰的路径。
它不是先想“我要做哪些行业产品”，而是从一个更底层的判断开始：
模型会持续变强，所以产品底座应该尽量轻。
如果模型会持续变强，Harness 就不应该变成一个沉重的规则系统，而应该保持统一、轻量、可扩展。它负责工具调用、上下文管理、状态维持、权限控制和审计机制，让模型能力的提升能够直接转化为产品能力的提升。
接着，Anthropic 需要让这个判断自我强化。
Claude Code 就承担了这个角色。编程任务天然可验证，开发者的真实使用会产生大量任务轨迹和反馈信号。这让 Claude Code 不只是开发者工具，也成为模型后训练飞轮的一部分：模型越强，Claude Code 越好用；Claude Code 越好用，真实任务数据越多；这些数据又反过来帮助模型继续变强。
在模型和 Harness 形成飞轮之后，Anthropic 开始进入高价值行业。
它优先选择生命科学、医疗、法律、金融、私募交易等场景，不是因为这些行业最容易，而是因为它们同时具备高合规、高客单价、工作流可拆解的特点。这些场景天然适合“AI 起草，人类审核”，也更能发挥 Anthropic 在安全、可靠和企业可信度上的品牌优势。
行业能力并不是通过重做产品来实现，而是通过 MCP、插件和 Skill 加载到同一个 Harness 上。
MCP 负责连接外部数据、工具和系统；插件负责组织和按需加载能力；Skill 负责沉淀行业经验。这样，Anthropic 每进入一个新行业，真正增加的是行业能力包和具体任务入口，而不是重新开发一套智能体运行时。
最后，Anthropic 通过不同的产品接触面进入用户已经工作的地方。
开发者在终端和编辑器里工作，Claude Code 就进入终端和编辑器；白领在办公软件和浏览器里工作，Claude 就进入办公软件和浏览器；企业员工在内部系统和 SaaS 里工作，Claude 就通过连接器和扩展进入这些系统。
把这条路径连起来看，Anthropic 的产品逻辑是：
```
模型持续变强
↓
Harness 保持轻量、统一、可扩展
↓
Claude Code 形成后训练飞轮
↓
MCP / 插件 / Skill 承载行业能力
↓
进入高价值工作流
↓
通过产品接触面进入用户已经工作的地方
↓
Claude 从幕后模型走向前台工作入口
```
这条路径解释了为什么 Anthropic 的产品看起来很多，但底层逻辑其实很统一。
Claude Code、MCP、Skill、插件、办公软件插件、浏览器扩展、行业能力包，并不是一组零散发布。它们共同服务于同一个方向：用一个统一的 Harness，把越来越强的模型接入越来越多真实工作流。

---
## 9. 真正的胜负手：谁拥有企业工作的智能入口
走到最后，Anthropic 这套产品布局真正要回答的问题，不是“下一个行业产品是什么”，也不是“Claude 又接入了哪些工具”。
真正的问题是：
未来企业里的知识工作，会从哪里开始？
过去，企业工作的入口是一个个确定的软件。
销售打开 CRM，分析师打开金融终端，律师打开法律数据库，员工打开办公软件，工程师打开代码编辑器。每一个软件都对应一个相对固定的工作场景，也各自拥有一部分用户入口和工作流。
模型最初进入企业时，更多是作为这些软件背后的能力层存在。用户仍然在原来的产品里工作，只是在某些环节调用 AI：帮我总结一段文档，生成一封邮件，解释一段代码，起草一份合同。
但 Anthropic 想推动的变化，不只是“在原有软件里加一个 AI 功能”。
它真正想做的是让 Claude 走到工作流前台：用户先向 Claude 描述目标，再由 Claude 调用工具、连接数据、理解上下文、组织信息，并把任务推进到下一个状态。
这会改变企业软件价值链里的位置关系。
传统 SaaS 不一定会消失。企业仍然需要系统记录客户、管理合同、保存病历、处理审批、承载权限和审计。这些系统长期积累的数据、流程和合规能力不会被轻易替代。
但它们的位置可能会变化。
一部分系统会继续作为记录系统存在，一部分工具会变成 Claude 调用的连接器，一部分办公软件会变成最终编辑、确认和交付的界面。真正被重新分配的，是中间那层最有价值的工作：理解任务、调动上下文、组织信息、形成初步判断，并推动流程继续向前。
这也是为什么 Harness 如此关键。
如果没有统一 Harness，Claude 很难稳定进入这么多不同工作场景。每进入一个行业，都要重新做工具接入、权限管理、上下文处理、状态维持和审计机制，扩张成本会非常高。
但如果 Harness 足够统一、轻量、可扩展，Anthropic 就可以不断把新的行业能力加载上去：通过 MCP 连接外部系统，通过 Plugin 组织任务能力，通过 Skill 沉淀行业经验，再通过不同产品接触面进入用户已经工作的地方。
这时，Claude 就不只是一个模型，也不只是一个聊天工具，而是有机会成为企业知识工作的智能入口。
如果这条路径跑通，Anthropic 会获得比模型调用更高的位置。它不只是提供推理能力，而是参与企业工作如何被发起、组织、执行和交付。模型层、运行时、行业能力和用户入口被连接到一起，Claude 就会从幕后能力变成前台入口。
如果这条路径没有跑通，Claude 依然会是一家重要的模型供应商。它可以继续给垂直 AI 应用、企业软件和开发者工具提供能力，但用户入口和工作流仍然主要掌握在传统 SaaS、垂直 AI 公司和企业内部系统手里。
所以，这场竞争真正决定的不是 Anthropic 能不能多做几个行业包，而是：
Claude 能不能从“被调用的模型”，变成“发起工作的入口”。
这也是我看 Anthropic 产品布局时最关心的地方。
Claude Code、MCP、Skill、Plugin、办公软件插件、浏览器扩展、行业能力包，看起来是很多不同产品。但放在同一条线上看，它们都指向同一个方向：
用一个统一的 Harness，把越来越强的模型接入越来越多真实工作流。
理解了这一点，再看 Anthropic 的产品矩阵，就不再是零散发布，而是一套非常一致的产品系统。
