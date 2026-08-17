# 我实现了 `/goal`，但人还是不能离开

*Goal、Permission 与 Sandbox 如何共同支撑 Coding Agent 的长程任务*


## 为什么我要实现 `/goal`

我实现 `/goal`，不是为了让模型单次运行更久，而是为了让人不再逐轮接棒。过去每轮回复后，
人都要决定是否继续；模型说完成时，人还要判断是否真的完成。工作由模型执行，人却仍是
agent loop 的时钟。

当目标明确、验收证据可以在执行中产生、实现路径可以交给模型时，逐轮确认不再带来相应的
控制价值。监督单位应该从 turn 提升到 task。

`/goal` 因此只做一件事：让用户一次定义目标和完成条件，再由系统持续推进，直到目标达成或
需要人作出新的决定。它不替模型选择实现步骤，也不改变工具权限。

## 我是怎么实现 `/goal` 的

要把这种 task 委托落到系统里，必须回答三个问题：

1. 目标是什么，什么证据算完成；
2. 谁来判断任务已经完成；
3. 判断之后，系统怎样继续、暂停或停止。

它们分别对应 Goal 契约、独立 Judge 和 Goal Controller。

### Goal 契约定义什么

Goal 首先是一份由用户定义的自然语言完成契约。用户不再逐轮描述下一步，而是在任务开始时声明：

```text
/goal 完成 permission runtime 重构；运行相关测试、mypy 和 ruff；
      不弱化测试，不修改无关行为；最多运行 20 turns
```

它不要求用户填写结构化字段，但内容需要说明：要完成什么、什么证据算完成，以及这次任务有
哪些约束。

```text
用户定义 Goal 契约
├── 目标是什么
├── 什么证据能够证明完成
└── 有哪些任务约束或不能做的事

程序提供运行边界
└── 最多自动运行多少轮
    防止错误目标或连续误判一直消耗 token
```

“不能做的事”在这里指任务约束，例如“不修改无关测试”，由 judge 根据执行记录验收。自动 turn
上限则由程序提供默认值，用户不需要每次声明，用来限制错误目标、连续误判和 provider 故障的
最坏成本。

### 如何判断任务已经完成

判断任务是否完成，本质上是比较两件事：Goal 要求的完成条件，以及当前任务实际产生的执行证据。

这项判断不能只依赖工作模型的自我总结。它可能没有运行测试就宣布“应该已经修好”，也可能只
完成了要求的一部分。因此，`/goal` 把判断交给一次独立、禁用工具的 Judge 调用。Worker 负责
执行任务，Judge 只检查完成条件是否已经被执行记录证明。

如果 Goal 要求测试通过，记录中就必须出现实际的测试命令、退出状态和结果；“应该能过”不构成
证据。`/goal` 设立时还会标记本次任务的证据起点：旧对话可以帮助 Worker 理解背景，但只有
`/goal` 之后产生的执行记录才能证明当前任务完成，避免用任务 A 的测试结果证明任务 B。

### Goal Controller 怎样工作

Goal Controller 包在 Engine 外面。它把 Goal 契约作为初始输入调用 Engine，收集本轮输出和执行
记录，再把 Goal 契约与当前记录交给独立 judge。Judge 给出判决后，Controller 决定停止、暂停，
或者把未完成的原因组织成下一次 Engine 输入。

```text
用户设置 Goal 契约
        │
        ▼
Goal Controller
        │
        │ 初始输入
        ▼
      Engine
模型工作、调用工具、产生输出
        │
        ▼
Controller 收集本轮输出与执行记录
        │
        │ Goal 契约 + 当前执行记录
        ▼
   独立 Judge
        │
        ├── MET
        │    └──> Controller 写入完成状态并停止
        │
        ├── ERROR
        │    └──> Controller 保留 Goal 并暂停
        │
        └── NOT_MET
             │
             ▼
       自动 turn 预算还有剩余？
             ├── 否 ──> 保留 Goal 并暂停
             │
             └── 是
                  │
                  ▼
          Controller 把 Judge 指出的缺口
          组织成下一次 Engine 输入
                  │
                  └────────> 再次调用 Engine
```

### Goal Controller 的最小伪代码

把状态展示拿掉以后，Controller 本质上就是包在 Engine 外的一层循环：

```text
goal = 用户定义(
    目标是什么,
    什么证据算完成,
    有哪些任务约束,
)

max_turns = 程序默认值

next_input = goal
evidence = []

for turn in range(max_turns):
    output, new_evidence = engine(next_input)
    evidence += new_evidence

    verdict, reason = judge(goal, evidence)

    if verdict == MET:
        return 完成

    if verdict == ERROR:
        return 暂停

    # NOT_MET
    next_input = reason

return 暂停  # 达到自动运行上限
```

Controller 只有两个工作函数：调用 Engine 和调用 Judge。Judge 输出的是判决，Controller 才负责
状态转换：`MET` 停止，`ERROR` 暂停，`NOT_MET` 在预算允许时继续，否则同样暂停。

> 证据表明尚未完成，才能继续；判官无法判断，系统必须暂停。

Goal 因此不是贴在 prompt 上的一句“请持续努力”，而是一个根据证据决定继续、暂停或停止的任务
控制器。

到这里，我第一次感到人真的可以离开终端了：设定 goal，让 worker 工作，让 judge 接 turn，
完成后再回来验收。

然后它停在了一次 permission 上。


## 为什么有了 `/goal`，人还是不能离开

Worker 想执行一条 Bash 命令，permission checker 返回了 `ASK`。

这在交互式 REPL 里很合理。系统无法确定一个动作是否应该执行，于是把决定交给当前在线的
人。人读完命令和上下文，选择允许或拒绝。

但我设置 Goal 的目的，就是不再一直守在电脑前。此时 `ASK` 暴露了它隐藏的前提：

> ASK 不是一个授权结论，而是一项实时交接协议。它假设另一个有权决策的人此刻在线。

当人不在线，ASK 只能走向三个结果：等待、退化成拒绝，或者被粗粒度地当成允许。前两种会
让长程任务停止；最后一种虽然让任务继续，却把“无人运行”偷换成了“无人约束”。

我这才意识到，Goal 只拿走了一根人工接力棒。人留在 agent loop 里，至少还承担着另外两种
职责：

1. 判断一个副作用是否获得授权；
2. 监督动作执行后不会影响不该影响的地方。

它们分别对应 Permission 和 Sandbox。


### 还缺 Permission 与 Sandbox

很多系统把 permission 和 sandbox 都画成“安全设置”，但它们不是同一个开关。

Permission 回答：

> 这个具体副作用有没有授权？

Sandbox 回答：

> 无论授权判断是否正确，动作实际上最多能碰到什么？

前者是 authorization，后者是 containment。Permission 依赖人或机器对用户意图的判断；
Sandbox 依赖操作系统对文件、网络、进程和环境的强制约束。

两者的差异可以粗略写成：

| | Permission | Sandbox |
|---|---|---|
| 核心问题 | 该不该让它做 | 做起来最多能影响什么 |
| 主要依据 | 用户意图、规则、动作语义 | 已安装的 runtime boundary |
| 失败方式 | 错误批准或错误拒绝 | 边界不完整、实现可绕过或静默降级 |
| 不能替代什么 | 不能限制批准后的真实后果 | 不能判断动作是否符合用户意图 |

这也给出了一个理解 agent 风险的简单模型：

```text
预期风险
≈ 危险动作被错误放行的概率
× 错误动作能够造成的影响范围
```

Permission 主要降低第一项；Sandbox 主要降低第二项。只优化其中一项，都不足以支撑人离场后的
长程任务。到这里，`/goal` 留下的问题已经明确：系统不仅要让任务持续推进，还要在没有人实时
看守时，处理动作授权并限制错误动作的最坏后果。


## 调研 Claude Code 与 Codex：先判断意图，还是先建立边界

为了决定自己的 permission 应该怎样演进，我调研了 Claude Code 与 Codex。

这不是为了评判谁更安全。两者现在都同时使用规则、模型判断和 OS sandbox，最终形态正在趋同。
真正值得比较的是：它们把主要控制点放在哪里，优先降低哪个风险变量。

### Claude Code：先判断动作是否符合用户意图

Claude Code 的 Auto mode 会让一个独立 classifier 在动作执行前判断：动作是否超出用户请求、
是否指向未识别的基础设施、是否不可逆或具有破坏性，以及是否可能受到 hostile content 驱动。

显式 allow/deny rules 和确定性的已知安全动作先处理，剩余动作再进入 classifier。Classifier
阻止时，Claude 会收到理由并寻找替代方案。它擅长回答纯命令规则难以表达的问题，例如一次
push 是否指向受信任分支、一个部署目标是否属于生产环境、删除的是本轮临时产物还是既有数据。

这条路线优先提高 authorization judgment 的质量，也直接减少逐动作 permission prompt。
但 classifier 仍然是概率模型。一次错误批准之后，真实后果取决于执行环境拥有的能力。

Claude Code 现在也提供 native sandbox：macOS 使用 Seatbelt，Linux 使用 bubblewrap，限制
Bash 及其子进程的 filesystem 和 network。Sandbox 内的 Bash 可以自动执行，越界或无法
sandbox 的命令再回到普通 permission flow。它的文档同时明确说明，Read、Edit、Write 等
内置文件工具仍直接使用 permission system，而不是运行在 Bash sandbox 中。

参考：
[Claude Code Permission Modes](https://code.claude.com/docs/en/permission-modes) ·
[Claude Code Sandboxing](https://code.claude.com/docs/en/sandboxing) ·
[Claude Code Permissions](https://code.claude.com/docs/en/permissions)

### Codex：先建立边界，再审核边界例外

Codex 的默认本地路径先建立一个 OS-enforced sandbox。`workspace-write` 允许 agent 在工作区内
读代码、修改文件和运行常规命令，网络默认关闭；写工作区外路径或请求网络时，再进入 approval
flow。

因此 Codex 把两个控制明确拆开：sandbox mode 决定技术上能够做什么，approval policy 决定
什么时候必须停下来取得授权。

Auto-review 也不是取消 sandbox。它只替换原本处理 approval request 的人：边界内动作无需
额外 reviewer；sandbox escalation、blocked network request 或有副作用的外部工具调用，才进入
automatic reviewer。Reviewer 失败、输出不可解析或命中高风险策略时，动作不执行。

这条路线优先限制 blast radius。Reviewer 仍可能误判，但它审核的是一个已经需要越界的例外，
而不是给 agent 永久获得宿主权限。

参考：
[Codex Agent Approvals & Security](https://learn.chatgpt.com/docs/agent-approvals-security) ·
[Codex Sandbox](https://learn.chatgpt.com/docs/sandboxing) ·
[Codex Auto-review](https://learn.chatgpt.com/docs/sandboxing/auto-review)


## 我的选择：先限制最坏后果

我的问题发生在长程任务中。

人在场时，错误批准一次 permission，还可能在下一秒按下 Ctrl+C；人离场后，一次错误可能沿着
后续 turns 持续放大。此时我首先需要的，不是一个更自信的 yes/no，而是任何 yes/no 判断错误时，
最坏后果都有上限。

因此我选择 boundary-first：先把模型可控副作用放进可信的 runtime boundary，再让自动审批器
根据用户授权和具体动作，处理低频、精确的边界例外。

这不是照搬 Codex，也不是拒绝 Claude Code 的 classifier。OpenHarness 的 permission reviewer
同样读取用户授权上下文和动作语义。我的选择只是改变 reviewer 的站位：

> Reviewer 不审核所有日常动作；它只审核超出基础授权的精确例外。

这也确定了后续重构的顺序：先统一基础授权，把本地部分安装成可信的 Sandbox boundary，再让
Permission 根据本地边界或外部策略提供的事实处理精确例外。


### Permission 从基础授权开始

长程任务开始前，人需要先定义 agent 已经拥有哪些基础能力。它不是一串等待逐条确认的工具调用，
而是当前 session 可以使用的能力范围。代码里，这份基础授权被组织成一个 Permission Profile。

Permission Profile 不只包含“项目里的文件权限”。它同时描述本地能力和外部能力：

```text
基础授权（Permission Profile）
├── 本地能力
│   ├── 哪些文件可以读写
│   ├── 是否可以联网、访问哪些域名
│   ├── 可以继承哪些环境变量
│   └── 子进程、超时和资源限制
│          │
│          ▼
│       由 Sandbox 安装并强制
│
└── 外部能力
    ├── Web
    ├── MCP
    ├── Browser
    └── Computer Use
           │
           ▼
        由外部策略与 Permission 控制
```

例如，当前默认 Profile 大致表达：

```text
文件
├── 当前 workspace：可以读写
├── .git：禁止写
├── .codex：禁止写
└── .agents：禁止写

网络
└── 默认关闭

环境变量
└── 只继承最小集合，不暴露凭据

进程
└── 有超时和资源限制

外部工具
├── Web：需要审批
├── MCP：需要审批
├── Browser：需要审批
└── Computer Use：需要审批
```

其中，本地部分交给 Sandbox，外部部分使用各自的策略与 Permission。两者都来自同一份基础授权，
但执行机制不同：

```text
Permission Profile
→ 希望允许什么

Sandbox
→ 用什么机制强制本地部分
```

同一份本地授权可以交给不同 backend 编译成运行时边界：

```text
同一份本地授权
       │
       ├──> Seatbelt 编译成 macOS 边界
       └──> Docker 编译成容器边界
```

不同 backend 能覆盖的能力可能不同。这张图只表示同一份授权意图可以交给不同机制实现，不能
预先假设它们拥有相同的覆盖范围。

这些基础授权在会话开始时确定，并在整个任务期间保持不变。Goal 只能在其中推进，不能因为任务
尚未完成就自行扩大权限。Permission Profile 是授权意图，不是执行证明：它说明人希望允许什么；
这些本地限制是否真的成立，需要 Sandbox 把它们安装成可以验证的运行时边界。


### Sandbox：把授权意图变成执行事实

配置写着“只能写 workspace”，不代表系统真的做到了。Sandbox 必须把授权意图安装成操作系统
强制执行的边界，并报告自己实际覆盖了什么、安装了哪些规则、哪些能力不支持，以及边界是否
经过验证。如果 backend 无法建立要求的边界，系统就停止，而不是静默退回宿主权限执行。

这也是为什么 Sandbox 不能只包住 Bash。Read、Write、Edit、Grep 和 Bash 都由模型控制，都能
读取或改变真实世界。启用统一 Sandbox 时，它们必须经过同一个 session boundary；subagent 也
继承同一份 runtime，不能从另一条工具路径重新获得宿主权限。

从概要设计看，Sandbox 不是一串执行步骤，而是一条稳定的会话边界：上层输入人的基础授权，
边界内部承接所有本地副作用，底层由操作系统强制执行，并向 Permission 报告真实的越界事实。

```text
                         人定义的基础授权
                   文件 / 网络 / 环境 / 进程
                              │
                       编译、安装、验证
                              │
                              ▼
┌──────────────── 当前会话的 Sandbox 边界 ────────────────┐
│                                                        │
│  唯一入口：来自 Agent / Subagent 的本地动作              │
│                         │                              │
│                         ▼                              │
│  统一的本地执行面                                       │
│  Bash / Read / Write / Edit / Grep                     │
│                         │                              │
│                         ▼                              │
│  操作系统强制约束                                       │
│  文件访问 / 网络访问 / 环境变量 / 子进程                 │
│                                                        │
│  Sandbox 同时报告：                                     │
│  · 实际覆盖了哪些副作用                                  │
│  · 实际安装了哪些规则                                    │
│  · 哪些能力当前无法支持                                  │
│  · 当前边界是否有效                                      │
└──────────────────────────┬─────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
         正常执行结果               明确的越界事实
                                        │
                                        ▼
                                    Permission
```

这张边界图表达了四条不变量：一个会话只有一条本地执行路径；边界由操作系统强制执行，而不是
依赖模型遵守 prompt；Sandbox 必须报告实际覆盖范围；无法建立或验证边界时，不能静默退回宿主
权限执行。

这条边界只对本地执行面作出保证。它可以限制本地进程是否联网，却无法限制一次 Web、Browser、
MCP 或 Computer Use 调用在远端产生什么副作用。因此，这些外部能力不能被包含在本地 Sandbox
的安全结论里，而要单独建模和授权：

```text
本地 Sandbox 覆盖
└── 文件 / 命令 / 网络 / 环境 / 进程

本地 Sandbox 不覆盖
└── Web / Browser / MCP / Computer Use
        │
        └──> 使用独立的外部能力策略和 Permission
```


> Permission 表达人的授权；Sandbox 把这份授权变成可以被信任的执行事实。


### Permission：只授权精确、一次性的例外

Permission 授权的对象，不是某个 Agent，也不是某个工具的永久使用权，而是基础授权之外的一项
具体动作。Goal 定义任务要到达哪里，但不会因此扩大基础授权。留在基础授权内的动作可以直接
执行；超出基础授权的动作，只有能够表达成精确例外，并且没有命中 hard deny，才进入审批。

假设基础边界允许修改 workspace，但禁止网络。Agent 运行测试时需要访问 `pypi.org`。系统请求的
不应该是“允许 Bash”或“允许联网”，而应该是：是否允许这个最终动作访问 `pypi.org`？

为了防止一次批准漂移成更大的权力，这份请求必须绑定动作的最终参数、当前基础授权与运行时
边界、所需的最小能力变化，以及数据从哪里流向哪里。本地请求的事实来自 Sandbox 返回的越界
结果；外部请求的事实来自外部策略、工具与服务身份。参数被 hook 改写，或者边界、策略发生
变化，原来的批准就不再有效。

```text
基础授权 + 最终动作 + 运行时事实 + 数据流向
                    │
                    ▼
              精确权限请求
                    │
                    ▼
                Permission
          ┌─────────┼─────────┐
          ▼         ▼         ▼
        拒绝      无法判断     批准
          │         │         │
        不执行      Park       ▼
                           一次性批准
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
              本地越界                   外部调用
        Sandbox 安装并验证临时边界     放行这一次绑定工具
        原动作重试一次后销毁          与最终参数的调用
```

这里还要区分两个问题：谁来审批，以及批准后能得到什么。Permission 并不固定指向一个 LLM
判官。当前实现提供两种审批方式：

```text
精确权限请求
      │
      ├── Manual
      │     └── Park，等人稍后批准或拒绝
      │
      └── Auto
            └── 独立 LLM Reviewer
                ├── 批准
                ├── 拒绝
                └── 无法判断 / 审批失败 → Park

无论由谁批准
      │
      ▼
同一份精确、一次性的授权凭证
```

“精确”意味着批准不能被另一组参数、另一条边界或另一种外部策略复用；“一次性”意味着批准被
消费一次后立即失效，不会修改基础授权。对于本地越界，批准不是关闭 Sandbox，而是在原边界上
安装并验证一个临时能力；对于外部调用，批准只控制这一次调用是否发生，不声称能够限制远端
后果。

OpenHarness 当前不允许一次审批自动升级成项目级规则，也不提供 Full Access。重复出现的合理
能力，应由人显式写入基础授权，再由 Sandbox 重新安装和验证；一次审批只解决眼前这一个例外。

> Permission approval 不是绕过 Sandbox，而是授权一个精确、一次性的例外。

手动模式会直接 Park，把问题留给稍后回来的人；自动模式则先由 LLM Reviewer 判断，无法判断或
审批失败时同样 Park。两条路径都不要求一个人必须实时在线。


### Park：把未决授权变成可恢复状态

Reviewer 可以批准或拒绝，也可能无法判断、调用失败，或者发现 backend 无法安装获批的临时
边界。最后这些情况都不能被当作普通工具错误。否则 Goal 会认为任务尚未完成，worker 下一轮
再次尝试同一个动作，自动控制环只会空转。

当前设计会保存这次精确请求和它所依据的授权与边界事实，然后 park session。终端不必一直阻塞，
人也不必当场出现。人回来后可以查看请求，选择批准或拒绝，再显式 resume；如果参数或边界已经
变化，请求就必须重新审批。

Park 不是失败退出，而是一份可恢复的人机交接：

> 机器已经推进到当前能力边界。这里需要人的新决定，所以任务先释放执行资源，等决定出现后
> 再继续。

## 回到长程任务：Goal、Permission 与 Sandbox 如何闭环

现在再看长程任务，三个机制分别填补了人离场后留下的三个控制空位：

| 问题 | 机制 | 它不负责什么 |
|---|---|---|
| 任务是否继续、何时完成 | Goal | 不授予新的能力 |
| 这一次例外是否获得授权 | Permission | 不负责强制本地边界 |
| 本地动作实际上最多能影响什么 | Sandbox | 不判断动作是否符合人的意图 |

三者不是依次执行的三个步骤。Goal Controller 包在 Engine 外面，控制任务是否继续；Permission
与 Sandbox 则守在 Engine 的动作边界，控制一次动作能不能发生，以及实际最多能产生什么后果。

```text
人定义 Goal 契约与基础授权
              │
              ▼
┌──────────────────── Goal Controller ────────────────────┐
│                                                        │
│  调用 Engine / worker                                  │
│          │                                             │
│          │ 提出动作                                    │
│          ▼                                             │
│  ┌─────────────── 动作边界 ─────────────────────────┐  │
│  │                                                  │  │
│  │ 本地动作                                         │  │
│  │ Sandbox 强制基础边界                             │  │
│  │ 越界时由 Permission 审核精确例外                 │  │
│  │                                                  │  │
│  │ 外部调用                                         │  │
│  │ Permission 根据外部策略决定是否允许调用          │  │
│  └──────────────────────┬───────────────────────────┘  │
│                         │                              │
│              ┌──────────┴──────────┐                   │
│              ▼                     ▼                   │
│        执行结果或拒绝事实        未决请求被 park        │
│              │                     │                   │
│              ▼                     └──> 保存状态并暂停  │
│        进入本次执行记录                                │
│              │                                         │
│              ▼                                         │
│          worker 本轮结束                               │
│              │                                         │
│              ▼                                         │
│         独立 Goal judge                                │
│       ┌──────┼─────────┐                               │
│       ▼      ▼         ▼                               │
│   NOT_MET   MET      ERROR                              │
│       │      │         │                               │
│   再次调用   停止      暂停                             │
│   Engine                                                │
└────────────────────────────────────────────────────────┘
```

Goal 不直接执行工具，也不改变权限。它只在 worker 一轮工作结束后，根据 judge 的判断决定是否
再次调用 Engine。Permission 与 Sandbox 也不判断任务是否完成，它们只守住动作发生的边界。

如果 Permission 已经产生未决请求，Goal Controller 会在调用 judge 之前暂停。因为更多推理不会
产生新的授权；继续启动 worker，只会让长程任务围绕同一个能力缺口空转。


### 结论：人不再是 agent loop 的时钟

回头看，我真正想解决的并不是怎样让模型一次运行更久。

我想改变的是人的位置。

过去，每一个关键节点都要求人实时在线：

```text
模型完成一轮
→ 人决定是否继续
→ 人处理权限请求
→ 人判断任务是否完成
```

现在，人先定义目标、完成条件和基础授权，然后可以离开：

```text
人定义目标、完成条件和基础授权
              │
              ▼
        系统持续推进任务
              │
        ┌─────┼──────────┬──────────┐
        ▼     ▼          ▼          ▼
     目标完成  达到上限   无法判断   需要新的授权
        │     │          │          │
        └─────┴──────────┴──────────┘
                      │
                      ▼
             人回来验收或作出决定
```

人并没有退出责任链。目标仍由人定义，基础能力仍来自人的授权，最终结果仍需要人的验收。变化的
是，人不再需要守在每一个 turn 和每一次工具调用旁边。

Goal 接管任务的持续推进与完成判断；Permission 让边界例外只能获得精确授权；Sandbox 限制本地
动作的实际后果；park 则把无法自动解决的决定保存下来，等人方便时再处理。

人的注意力因此不再是 agent loop 的时钟。人可以离开，然后在任务完成，或者系统真正抵达人的
决策边界时再回来。
