# Content Management：如何为 Coding Agent 管理有限注意力

> 写于 2026-08-13

Coding Agent 的任务可以持续几十轮、几小时甚至更久，但 LLM 每一次推理只能接收一份有限输入。
Harness 因此必须不断决定：当前任务需要哪些信息，哪些证据仍然有效，模型此刻可以使用什么
能力，以及哪些历史应该退出。

Content Management 管理的就是这份不断变化的输入。它不只是 Context Window 接近上限时的
Compact，而是 Harness 在每次调用模型前，为下一次推理编译 Working Set 的完整过程。

本文基于 [OpenHarness](https://github.com/maisieyang/open-harness) 的系统设计，从两个范围展开：
一个 Session 内，信息如何进入、增长、压缩与隔离；跨 Session 后，长期知识和会话状态如何保存，
并在新的运行环境中重新进入 Context。


## 起点：Context 不是记忆，而是一次推理的工作集

LLM 的一次 API 调用本身是无状态的。所谓“模型记得之前发生了什么”，只是 Harness 在下一次
调用时，再次提交了相关信息。

这些信息可能来自很多地方：

```text
System Instructions       Project Instructions
Conversation              Tool Results
Goal State                Permission State
Memory Index              Skills
Plugin Capabilities       Available Tools
              \             /
               选择、排序、裁剪、塑形、压缩
                          │
                          ▼
                 本次推理的 Working Set
                          │
                          ▼
                     LLM 判断与行动
```

因此，Context 并不是一个自然存在、不断追加的容器。每次调用模型之前，Harness 都在从不同来源
重新构造它。我更愿意把这个过程理解成：

> Harness 在为下一次推理编译 Working Set。

这个 Working Set 的质量至少有五个维度：

- **充分**：当前判断依赖的事实不能缺失；
- **可信**：事实来源与信息损失边界必须清楚；
- **当前**：最新状态必须能够覆盖已经过时的状态；
- **适配行动**：模型看到的能力应当符合当前模式和权限；
- **足够小**：无关信息不能无限竞争容量与注意力。

Context Window 解决的是“装得下多少”，Content Management 解决的是“此刻应该让模型看到
什么”。旧错误、冗长说明和不适用的 Tool 即使没有撑满窗口，也会竞争注意力并改变行动选择。

因此，更大的 Context Window 只能延后容量耗尽，不能替代 Harness 对信息与能力的选择。
OpenHarness 把这种选择实现为对下一次 Working Set 的持续编译。


## OpenHarness 如何编译下一次 Working Set

从系统视角看，OpenHarness 的 Content Management 运行在两个时间尺度上：

- **一个 Session 内**：持续编译 Working Set，控制模型看见的信息、可用的能力，以及
  Conversation 的增长与压缩；
- **跨 Session**：保存值得长期复用的知识和能够精确恢复的会话状态，并在下一次启动时重新
  建立当前 Context。

### 一个 Session 内：持续编译 Working Set

#### 选择什么进入 Working Set

一次 Agent 推理所需的信息可以粗略分成三类：

| 信息 | 它回答的问题 | 典型来源 |
|---|---|---|
| 任务 | 现在要完成什么 | 用户消息、Goal、Project Instructions |
| 证据 | 已经知道和验证了什么 | Conversation、Tool Results、Project Memory |
| 能力 | 现在可以采取什么行动 | Tools、Skills、Plugins、Permissions |

这三类信息不能用同一套策略处理。任务约束需要稳定可见；测试结果和错误信息需要保留来源；
能力描述则应该根据当前模式选择。

最直接的方案是把所有可用信息一次性拼进 Prompt。它实现简单，也最大程度避免“模型不知道系统
拥有什么”。但它把发现能力所需的索引和真正执行任务所需的正文混在了一起。能力越多，当前
任务越容易被暂时无关的信息包围。

我选择渐进式暴露：Working Set 先提供短小、可区分的索引，只有模型或用户选择某项能力后，
才加载完整正文。

- Project Memory 先注入轻量索引，模型需要时再通过 `MemoryShow` 加载具体正文；
- Skill catalog 先暴露名称与简短 description，`LoadSkill` 再展开正文；
- Plugin 只把启用后的能力并入相应目录，不把整个 Plugin 内容放进 Prompt。

这个选择减少了常驻 Context，也让能力来源更清楚。代价是模型可能需要多一次读取，Catalog
的名称和 description 也必须足够准确，才能支持正确选择。

#### System Prompt 如何承载这些选择

这些设计最终必须变成模型在本次推理中能够读到的规则。OpenHarness 的 System Prompt 根据
当前环境和能力，按固定结构动态组装：

```text
Base Instructions
      + Tool Catalog
      + Skill Catalog
      + Environment
      + Project Instructions
      + Memory Rules 与 Index
      ↓
本次推理使用的 System Prompt
```

稳定、跨项目的行为放在 Base Instructions，例如如何面对 Tool error、如何报告精确验证命令
的结果。具体能力来自当前 Tool 与 Skill catalog；工作目录和运行环境来自 Environment；项目
自己的开发约束来自 Project Instructions；Memory 等可选部分只在对应能力存在时加入。这种组装
方式让规则的来源和作用范围保持清楚，也避免把所有可能的说明永久塞进每一次输入。


#### Default、Plan 对模型可见能力的塑形

Content Management 不只决定模型看见什么信息，也决定它看见什么能力。Default 是 Session 的
正常工作状态，使用当前已经启用的完整能力面。Plan 面向“先调查，再决定是否行动”：模型可以
读取代码、搜索资料和形成方案，但在用户明确批准之前，看不见修改、执行或委派任务所需的 Tool。

OpenHarness 先组装当前 Session 的能力基线：

```text
内建 Tools
+ MCP Tools
+ LoadSkill
+ Memory Tools
+ Bundle 筛选
    ↓
effective_registry
```

`effective_registry` 是 Default 直接使用的能力面。进入 Plan 后，系统才为这一轮生成收窄后的
Tool catalog：

```text
effective_registry
    ├── Default：直接使用
    └── Plan：只保留 read-only、non-delegated Tools
```

Plan 的筛选不是硬编码删除 Write、Edit、Bash 和 Agent，而是读取每个 Tool 声明的 metadata：

```python
tool.is_read_only
and tool.execution_domain is not DELEGATED_RUNTIME
```

因此，新接入的 MCP Tool 只要正确声明 metadata，也会自动进入或退出 Plan 的能力面。Plan 同时
保留两层约束：模型只能看见筛选后的 Tool catalog；完整 registry 留在执行层，用来拒绝伪造的
隐藏 Tool 调用。只读不是一句要求模型主动遵守的 Prompt，而是模型可见能力与运行时执行边界的
共同结果。

#### Goal：把完成条件加入 Working Set

Goal 解决的是另一类问题：“不要因为一次回复结束就停止”。用户给出可验证的完成条件后，Agent
应持续工作、留下证据，并在条件尚未满足时自动继续。

Goal 不参与 Tool 筛选。它保留当前 Mode 的 registry，把完成条件加入 System Prompt，并在
Agent 自然结束一次回复后，让独立 Judge 检查 Conversation 中的证据：

```text
当前 Mode 的 registry
        +
Goal 完成条件进入 System Prompt
        ↓
Agent 自然结束一次回复
        ↓
独立 Judge 检查 Conversation 中的证据
    ├── 条件满足：结束 Goal
    └── 条件未满足：注入继续工作的输入
```

Goal 在 Plan 中也可以保持可见，让规划围绕完成条件展开，但 Judge 只在 Session 回到 Default 后
运行。Default 提供能力基线，Plan 收窄模型可见的行动空间，Goal 则控制整个任务什么时候结束。
三者共用同一个 Agent Loop，却不需要设计成三套 Tool registry。


#### 在每个 Tool Result 上控制信息增长

长程 Agent 中，Context 增长最快的部分通常不是用户聊天，而是文件内容、搜索结果、测试日志、
Traceback、网页正文和 Subagent 返回。

因此，信息增长的第一道边界不应该等到最终 Compact，而应该落在每一个 Tool Result。

永远返回完整输出最忠实，却无法控制一次调用对 Context 的占用。只保留头部虽然简单，又会
系统性地丢掉 pytest 汇总、命令退出状态和 Traceback 根因，因为这些信息经常位于结尾。每次都
让另一个 LLM 总结 Tool Result，则会增加延迟、成本和新的语义损失。

我选择为单次结果设置预算，并在结果过长时保留 head + marker + tail：

```text
输出开头
...
[truncated ...]
...
输出结尾
```

开头帮助模型确认命令、目标和输入形态，结尾保留最终结果与错误根因，marker 则明确告诉模型：
这里发生过信息损失。

Marker 不是装饰。没有 marker，模型容易把“这一次 Tool Result 中没有看到”解释成“原始数据
里不存在”。有 marker，模型至少知道自己面对的是不完整证据。

如果真正需要的信息位于被截掉的中段，模型可以按需恢复：

```text
Read：建立文件整体形态
  ↓
发现中段被截断
  ↓
Grep：按名称或 anchor 精确找回事实
```

这个方案主动接受了一个代价：模型有时需要额外调用工具。但它让单次结果体积可控，同时没有
把信息损失伪装成完整证据。

这一层只控制一次 Tool Result 进入 Conversation 时新增多少信息，不处理已经累积的历史，也不
负责判断哪些旧语义应该继续保留。


#### 清理旧 ToolResult：先做确定性减负

单条 Tool Result 已经受到入口预算控制，Conversation 仍然会随着任务推进持续增长。超过整体
阈值后，OpenHarness 不再按 Tool 名称猜测哪些结果“值得清理”，而是在完整 Conversation 上
同时计算两条 recent 边界：

- Message 维度：最后 N 条 Message，默认 12，可通过
  `OPENHARNESS_COMPACT__PRESERVE_RECENT_MESSAGES` 调整；
- Tool 维度：按 `tool_use_id` 配对后，最近 3 次已经完成的 Tool 交互。

这两个集合不是先后嵌套，而是并行计算后取并集。这样，如果最后 12 条 Message 里包含 5 次
Tool 交互，这 5 次都会原样保留；如果最近 12 条全是普通对话，位于更早位置的最近 3 次 Tool
交互仍然受到保护。

确定性清理的链路是：

```text
完整请求达到 Compact 输入预算
   ├── recent messages = last N messages（默认 12）
   └── recent tools = last 3 completed tool interactions
        ↓
两个保护集合取并集
        ↓
清理其他已完成 Tool 交互的 Result 正文
   ├── 不区分 Read、Bash、Agent、Web、Plugin 或 MCP
   ├── ToolUse 名称和输入参数继续保留
   └── ToolResult 正文替换为 [cleared]
        ↓
重新估算完整请求
   ├── 已低于阈值：直接使用清理后的 Conversation，不调用 Summary
   └── 仍然超过阈值：进入 Summary
```

ToolResult 被清理后，ToolUse 仍然保留。它记录了调用过什么工具、操作了什么对象、使用了哪些
参数。这样，模型知道这项行动已经发生；必要时，也可以据此重新获取当前状态。

清理只作用于已经完成、能够与 ToolUse 配对，并且位于 recent 保护范围之外的 ToolResult。它
不区分内建 Tool、Plugin 或 MCP，也不改写用户消息和 Assistant 结论。

清理后，系统重新估算完整请求。已经低于预算就直接继续；仍然过长，才用 Summary 压缩较早
历史，并原样保留 recent messages。

#### Summary：语义压缩 older，原样保留 recent

旧 ToolResult 清理后仍然超过预算，OpenHarness 才进入语义压缩。实现不再抽象讨论哪些信息
“应该”留下，而是先划出一条明确的物理边界：自动 Compact 默认保护最后 12 条 Message；用户
显式执行 `/compact` 时保护最后 2 条。边界以前是 `older`，边界以后是 `recent`。

```text
清理后的 Conversation
        │
        ├── older ──→ 追加专用 Handoff 请求 ──→ LLM Summary
        │                                      Tools = []
        │                                          ↓
        └── 原始 recent ───────────────────────────┐
                                                   ↓
下一次 Conversation = boundary marker + Summary + 原始 recent
```

这里有三项由代码保证。第一，只有 `older` 会发给 Summary 模型；`recent` 从原始 Conversation
直接切出，不经过清理或改写。第二，Summary 调用禁用全部 Tools，并在历史末尾追加一条专用 User
Message，避免模型把任务理解成继续对话。第三，只有拿到非空 Summary 后才替换历史；自动 Compact
失败时继续使用已经完成 ToolResult 清理的 Conversation，显式 `/compact` 失败则报告原因并保持
原 history 不变。

当前 Summary Prompt 把模型设定为下一位 LLM 的任务交接者，要求它输出结构化 Handoff，并保留
当前状态、关键证据、约束、标识与未完成工作。这些栏目和措辞可以继续迭代；真正稳定的设计边界
是：代码决定 `older` 与 `recent`、控制何时允许有损转换并负责重组，LLM 只负责把 `older` 转换
成较短的语义状态。

Prompt Too Long 表示 Provider 明确拒绝了当前请求，原样重试没有意义。主请求遇到它时，系统
只重新编译一次上下文：保留预算内最大的、协议完整的 recent 后缀，把更早历史交给 Summary，
然后重建请求。第二次仍然过长就明确报错，不再继续删除 Conversation。

#### Subagent：为子任务编译独立 Working Set

Subagent 解决的是同一 Session 内的另一种边界：怎样让一段多步调查拥有自己的注意力空间，
又不把全部内部过程写回父 Conversation。

在实现上，`Agent` 只是一个普通 Tool。父模型调用它时提供 `description` 和一段完整 `prompt`；
`SpawnAgent.execute()` 通过 `dataclasses.replace()` 从父 `QueryContext` 构造子 Context，并把
`agent_depth` 加一。模型、cwd、Skills、Hooks、Sandbox、授权上下文和大多数任务工具继续继承，
但 Conversation、持久化所有权和可变 Permission lifecycle 被明确切开：

```text
父 Agent：Agent(prompt=完整子任务)
                ↓
新的 Conversation = [这条子任务]
                +
继承模型、cwd、Skills、Hooks、Sandbox 与授权上下文
                +
过滤 root-only Tools，重新塑形 Tool catalog 与 System Prompt
                +
创建独立 PermissionRuntime；禁用 Snapshot
                ↓
子 Agent 独立运行同一个 Agent Loop
                ↓
最终文本成为一个 Agent ToolResult
                ↓
父 Conversation 只增长一组 ToolUse + ToolResult
```

Subagent 使用独立 Conversation，但继承完成任务所需的运行环境，包括模型、cwd、Skills、Hooks、
Sandbox 和大多数 Tools。它的 Tool registry 与 System Prompt 会重新生成：Root Session 专属的
Memory 写入能力被移除，专用 Agent 还可以通过 `tool_filter` 进一步收窄能力面。

子 Agent 也不共享父级正在进行的 Permission 状态，并且不能写入可供 Resume 使用的 Snapshot。
它完成任务后，只把最终结果作为一条 Agent ToolResult 返回父 Conversation，内部消息和 Tool
轨迹不会全部进入父级 Context。

这个设计用明确的任务交接换取注意力隔离：父 Agent 必须在 `prompt` 中提供足够的目标、约束和
背景，但可以避免子任务的完整执行过程持续撑大父 Conversation。

### 跨 Session：长期知识与精确恢复

一个 Session 结束后，有两类信息需要继续存在：未来仍可能有用的语义知识，以及恢复当前会话
所需的精确状态。OpenHarness 分别用 Project Memory 和 Snapshot 保存它们，再由 Resume 在下一次
启动时与当前运行环境重新组合。

#### Project Memory：让长期知识按需回到 Context

Conversation 服务于当前 Session。Session 结束后，其中大部分过程都不值得继续保留，但有些
知识会持续影响未来工作，例如用户反馈、协作偏好、项目背景，以及无法从代码和 Git 重新推导的
外部事实。

这些知识如果只留在 Conversation 中，下一个 Session 就无法使用；如果每次都完整放进 Prompt，
又会让无关信息长期占用 Context。Project Memory 解决的是这组矛盾：把长期知识保存在 Prompt
之外，需要时再让它回到 Working Set。

OpenHarness 为每个项目维护独立的 Memory records。System Prompt 只放入一份轻量索引，告诉模型
“有哪些知识可能可用”；模型判断某项内容与当前任务相关后，再加载完整正文：

```text
Project Memory
      ↓
轻量索引进入 System Prompt
      ↓
模型判断当前任务是否需要
  ├── 不需要：正文不进入 Context
  └── 需要：按需加载正文
```

##### Memory Prompt 决定什么值得留下

存储只能解决“怎样保存”，不能判断“什么值得保存”。Memory Prompt 才是这套系统的语义控制层：
它要求模型先判断一项信息是否值得跨 Session 保留、是否无法从当前项目重新获得，再把它归入
四种类型之一：

| Memory 类型 | 它保存什么 |
|---|---|
| `user` | 用户的角色、目标、责任、知识与协作偏好 |
| `feedback` | 用户对工作方式的纠正或确认，以及背后的原因 |
| `project` | 无法从代码和 Git 推导的项目目标、背景与进展 |
| `reference` | 外部系统中重要信息的位置及其用途 |

Prompt 同时定义了负边界：能够从代码、Git 或稳定文档重新得到的信息，以及临时任务状态，不应
进入长期 Memory。它也规定了 Memory 的使用方式：相关时按需读取，用户要求忘记时删除；如果旧
Memory 与重新观察到的代码、测试或外部状态冲突，以当前证据为准，并更新或移除过时记录。

这里的责任分为两层：模型决定什么值得长期保存、属于哪种类型，以及什么时候读取或更新；
Harness 负责项目隔离、持久化和安全的读写边界。Memory 提供的是过去沉淀的知识，不是当前事实
的权威来源。

#### Snapshot：保存可以继续运行的 Session

Project Memory 保存经过选择的长期知识，Snapshot 保存的是当前 Session 的可恢复状态。

一次 Session 中不只有自然语言对话，还包含模型发起的 ToolUse、Tool 返回的 ToolResult、正在
等待处理的 Permission，以及其他会影响下一步执行的控制状态。如果只保存一段自然语言摘要，
重新启动后虽然大致知道“聊过什么”，却不一定知道工具调用进行到哪里、哪项权限正在等待决定，
以及下一步应该从哪个状态继续。

OpenHarness 在每次外层 Agent turn 结束或暂停时保存一次 Snapshot。这里的一次 Agent turn 可以
包含多轮 LLM 推理和 Tool 调用；只有当 Agent 自然回复、Permission 被暂停或显式 turn limit
触发时，才形成新的可恢复版本：

```text
正在运行的 Session
        ↓
typed Conversation + 可恢复控制状态
        ↓
Snapshot
        ↓
进程退出
        ↓
Resume 读取 Snapshot，继续这段 Session
```

每个 Snapshot 保存截至当前时刻的完整 typed Conversation 和控制状态，而不是本轮新增消息。
新的完整状态成为 `current`，原来的 `current` 被轮换进 `history`。因此，`history` 保存的是
一组 Session 状态版本，不是一条逐消息追加的事件队列。

`/clear` 也必须更新 Snapshot。它不只是清空当前进程里的 Conversation，还要把磁盘上的可恢复
状态一并清空；否则下一次 `--resume` 仍会恢复用户已经删除的旧 Session。

#### Resume：用过去的 Conversation 和现在的能力继续工作

Resume 不是重新启动已经退出的旧进程，而是在当前运行环境中重建一个可以继续工作的 Session。

Snapshot 提供过去已经发生的事实：typed Conversation、ToolUse 与 ToolResult，以及仍然可以
恢复的控制状态。当前运行环境则提供此刻真正可用的能力：Tools、Skills、Project Instructions、
Memory Index、Sandbox 和 Permission boundary。

```text
Snapshot 中的历史状态
        +
当前运行环境与能力边界
        ↓
重新编译下一次 Working Set
```

这两个来源不能互相替代。只相信 Snapshot，可能让已经关闭的 Tool 或过期的权限继续生效；只
相信当前环境，又会丢掉此前的对话、验证结果和未完成工作。因此，OpenHarness 保留“过去发生过
什么”，但用当前配置重新决定“现在能够做什么”。

Permission 等控制状态只有与当前安全配置兼容时才会恢复；System Prompt、Tool catalog 和
Memory Index 始终根据当前环境重新生成。Resume 恢复的是 Session 的连续性，不是旧运行环境的
全部权力。

这样，Project Memory、Snapshot 和 Resume 分别承担三个职责：Memory 保存可复用知识，Snapshot
保存 Session 状态，Resume 让这些历史在当前环境中重新成为可用 Context。


## 充分利用有限输入，不是塞得更多

Content Management 管理的不是一块不断扩大的存储空间，而是信息在 Agent 生命周期中的位置。

在一个 Session 内，Harness 选择进入 Working Set 的任务、证据和能力，限制 Tool Result 的增长，
清理较早历史，并在必要时用 Summary 完成语义压缩。跨 Session 后，Project Memory 保存可复用
知识，Snapshot 保存可恢复状态，Resume 再把过去的 Conversation 与当前能力重新组合。

更大的 Context Window 可以容纳更多信息，却不会自动判断哪些信息充分、可信、当前，以及适合
此刻的行动。Harness 的职责不是替模型思考，而是持续为下一次思考准备正确条件。

> 充分利用 LLM 有限的输入，不是把尽可能多的过去交给模型，而是为每一次判断编译一个足够、
> 可信、当前并且适配行动的 Working Set。
