# Agent Harness 的 Eval：不是给模型打分，而是建立受控实验能力

> 写于 2026-08-04
> 这是我在 [OpenHarness](https://github.com/maisieyang/open-harness)
> 中，从 5 个 prompt case、LLM judge 和 cassette，一路做到 8 组 capability eval
> 与 SWE-bench Lite 全量战役后的工程复盘。


## 引子：第一个 5/5 是骗子

我最早给 `focus_state` 做 eval 时，只写了 5 个对话 case 和两个简单 scorer：

```python
def score_parse_ok(result):
    return 1.0 if result.goal is not None else 0.0

def score_goal_keyword_match(result, expected_keywords):
    return 1.0 if any(kw in result.goal.lower() for kw in expected_keywords) else 0.0
```

第一次结果是 5/5。

但我无法回答一个最基本的问题：这 5/5 是因为 prompt 真能让模型正确理解任务，还是因为
`expected_keywords` 本来就来自输入，模型只要复述几个词就能通过？

分数没有告诉我系统好不好，只暴露了测量装置没有区分度。这个经历改变了我对 Eval 的定义：

> Eval 不是产出一个分数，而是让关于系统能力的判断变得可证伪、可重复和可归因。

一个个人 demo 可以展示几次成功结果；一个工程系统还必须说清楚：测的究竟是哪项能力，
输入来自什么分布，谁判定结果正确，实验条件有没有变化，以及失败如何进入下一轮改进。


## 一、Harness Eval 测的到底是什么

Agent harness 不是纯代码，也不是裸模型。它的行为来自两部分相乘：

```text
harness behavior = deterministic code × probabilistic model behavior
```

因此验证方式也必须分开：

- 路径解析、权限规则、JSON 校验、atomic write 等确定性逻辑，应该用 unit test。
- 裸模型在通用任务上的能力，属于 model eval。
- 模型看到特定 system prompt、tool registry、错误反馈和 memory index 后做出的行为，
  才属于 harness eval。

我后来把边界压成一句话：

> 凡是经过 LLM 输出翻译后才决定系统行为的部分，用 eval；确定性机制本身用 TDD。

同一个模块里两者可以同时存在。Permission checker 的 allow/ask/deny 求值是确定性的，
用单元测试；模型收到 permission denied 后会改道、重试还是放弃，是概率性的，要用 eval。

所以 eval 的覆盖单位不应该是“模块”或“功能”，而应该是**模型决策面**。


## 二、先画决策面，再谈 case 数量

项目演化到中期后，我从生产代码反推了 7 类模型决策面：

| 决策面 | 模型在做什么 | 当前证据 |
|---|---|---|
| Secondary pass | 输出 focus state、compact summary、完成判定、任务拆解 | focus、compact、verify 已覆盖；decomposer 未建 |
| Tool 选择与 input 构造 | 决定调哪个工具、参数怎么填 | `tool_choice` 单步 eval |
| Agentic loop | 消费工具结果、从错误恢复、决定是否继续 | `error_feedback` 单步探针；完整轨迹仍缺 |
| Inline side effect | 决定何时读写 memory 等非显式副作用 | `memory_decision` + `memory_read` |
| Skill / plugin 调用 | 决定何时加载哪个 skill | `skill_trigger` |
| Sub-agent dispatch | 决定是否委派、子任务 context 是否自足 | 已完成边界设计，等待真实失败触发 |
| End-to-end completion | 在真实仓库中完成完整任务 | SWE-bench Lite |

这张图解决了我早期犯过的一类错误：拿 `focus_state` eval 去比较模型强弱，甚至推断
project memory 架构是否可行。它测的是一个特定 secondary prompt 的结构化输出质量，
没有资格回答另一个决策面的架构问题。

“有 100 个 eval case”本身没有意义。100 个 case 如果都围绕 tool selection，sub-agent
委派仍然是零覆盖。反过来，一个 case 如果精准命中 load-bearing 的 fail-open 路径，
可能比几十个同质 case 更有价值。


## 三、每份 Eval 先写四个声明

为阻止 eval 被误用，我要求每份 dataset card 在跑之前先写四项声明：

1. **Capability claim**：这份 eval 声明系统在哪个决策面上达到什么能力。
2. **Input spec**：样本是什么形态、N 多大、从哪里来。
3. **Judgment spec**：每个 scorer 判什么，输出值具体是什么意思。
4. **Reference policy**：用哪个参照模型定 bar，其他模型的结果是 gate 还是信息。

同等重要的是 `Not designed for`。例如 `memory_read` 的 6/6 只证明模型在明确
must-read 和 restraint 场景下读对或克制，不证明模糊相关性已经解决；`verify_judge`
的 8/8 只证明清晰完成条件和两类注入样本，不证明边界模糊条件下判官仍然可靠。

Capability claim 是 Eval 的类型系统。没有它，同一个数字会被拿去回答任意问题；一旦
声明清楚，越界解读就会像类型错误一样显眼。


## 四、Eval 的核心不是 runner，而是 oracle

Runner、YAML loader、结果展示都可以买或重用。真正无法外包的是 oracle：谁说这次输出
算对，以及这个“谁”有多可信。

我使用的 oracle 硬度阶梯是：

| Oracle | 项目实例 | 性质 |
|---|---|---|
| 精确 `=` | 期望 tool 名是 `Grep`；skill slug 必须精确匹配 | 最硬、最便宜 |
| 轨迹不变量 | 被拒后不得原样重发；必须有后续动作 | 能证明“没有犯这类错” |
| Keyword / 存在性 | compact 后关键事实仍在 | 适合信息保真 |
| LLM judge | memory 类型是否合理 | 软、需要单独校准 |
| 人工判断 | dogfood 发现、金标 bootstrap | 覆盖广但贵、难规模化 |

纪律是：**能硬绝不软。** LLM judge 不是 eval 的默认配置，只是最硬 oracle 无法表达时
才使用的 scorer。

### 把开放问题重述成封闭检查

`memory_compact` 是最典型的例子。摘要没有唯一标准答案，如果直接问另一个模型“摘要写得
好不好”，得到的仍然是软判断。

我改了问题：不测文风和完整观感，只测应该活下来的事实有没有活下来。每个 case 在将被
压缩的旧消息中种植明确事实，例如端口、工具选择和待办项；压缩后用确定性 keyword 检查
事实回收，并加一条噪声不得进入摘要的反向探针。

这把开放式生成问题降维成了封闭存在性检查。6 个 case 在 qwen-max 上连续四轮 6/6，
证明的是信息保真底线，而不是“摘要质量完美”。

### 软判官也必须站到硬尺子上

`/goal` 使用独立 LLM 判断自然语言完成条件。既然判官本身也是概率模型，就不能因为它叫
“judge”而默认可信。

`verify_judge` 因此是一份 meta-eval：人工先给 `(condition, transcript)` 标出 pass/fail
金标，生产判官的 verdict 必须与金标精确相等。8 个 case 包含 3 个明确通过、3 个明确失败
和 2 个中英注入攻击，连续四轮 8/8。

它仍然只是一条回归底线。模糊条件需要多人标注或更软的 oracle，我没有为了扩大覆盖而
伪造一个确定答案。


## 五、Case 是预先注册的假设，不是成功示例

第一个 5/5 的问题，是 case 只在举例，没有预先声明什么会推翻设计。

后来每个 case 都绑定 capability ID 和 pass/fail assertion。跑模型之前，我已经写下：

- 哪个工具应该被选择；
- 哪些工具必须避免；
- input 的哪个字段必须包含什么约束；
- 哪种错误后不允许原样重试；
- 哪些事实必须进入 summary；
- 哪些副作用必须克制。

这让 case 从 example 变成 falsifiable hypothesis。失败后不能靠重新解释输出把它说成成功。

Eval 也会测错。`tool_choice` 曾要求“运行测试”的 Bash command 必须包含 `pytest`。模型连续
四次选择 `make test`，被 scorer 判失败。问题不在模型：合成环境没有项目上下文，测试命令
不可知；这个 assertion 实际测的是“猜测试栈”，不是“正确选择 Bash”。最终我删除了这一
过度指定的 input 断言，但保留 tool selection 维度。

修正错误 oracle 不是放水。放水是为了让分数上涨而移动规则；校准是证明规则测错了对象，
并把为什么改、改掉后留下什么缺口写进 dataset card。


## 六、概率系统的 gate 必须包含稳定性

一次通过不是稳定能力，一次失败也不一定是 regression。我给每个参照模型至少跑 N=4
真实画像，再按分布确定 pass bar。

项目里的 bar 不是统一的 100%：

- `tool_choice` 的 8 个 case 四轮零方差，所以 gate 是 8/8。
- `skill_trigger` 存在真实抖动，gate 是至少 7/9，并要求 7 个稳定绿 case 全部通过。
- `error_feedback` 是至少 8/9；benchmark 中的 14182 死亡链在四轮里有一次原样重试，
  它被保留为观察项，没有为了满分删掉。

Reference model 也必须写死。qwen-max 上的 bar 只声明参照系内的回归；换模型的红首先是
信息，不自动等于产品回归。真正的 cross-model 比较还需要固定第三方 judge、扩大样本并
移除 model-coupled assertion，不能把两个小样本结果直接排成模型排行榜。

多维 score 也不应该随手压成一个平均分。Tool selection 正确但 input 错，和 tool 选错但
input 碰巧包含关键词，是两种失败。每一维保留独立 reason，overall pass 采用所有必要维度
同时成立，而不是让一个高分抵消另一个关键失败。


## 七、Record / Replay 解决的是成本，不是今天的真实性

LLM eval 有三个运行模式：

| 模式 | 调用真实模型 | 写 cassette | 用途 |
|---|---:|---:|---|
| `live` | 是 | 否 | 探索、观察当前模型行为 |
| `record` | 是 | 是 | 为特定 prompt/model 建立新基线 |
| `replay` | 否 | 否 | 免费、确定性地重放已录行为 |

Cassette 让一次付费录制可以被无限次重放，也让 scorer、dataset loader 和结果聚合可以进入
普通测试节奏。Result metadata 进一步保存 model、dataset hash、prompt/rubric 全文、
git commit 和 dirty 状态，区分三种可重复性 claim：

- identity：这是不是同一个 prompt/dataset/rubric；
- content：半年后是否还能读到当时全文；
- state：当时运行的代码 commit 与工作树状态是什么。

但 replay 的语义必须严格收窄：

> Replay 证明“这份录制响应在当前 scorer 和 dataset 下仍然得到同一判断”，不证明今天的
> 模型仍然会产生这份响应。

当前 cassette key 只有 `(case_id, model, kind)`，不含 prompt hash，也没有自动 freshness
检查。修改 production prompt 后，如果忘记重新 record，replay 仍然可能全绿。Provider
更新模型、翻转默认参数后，旧 cassette 同样不会自己过期。

因此 record/replay 是成本与回归机制，不是当前真实性证明。当前模型行为只能通过受控 live
重录和 N 次画像更新。把 replay 绿写成“模型行为没有回归”，是对证据的越权解释。


## 八、Eval 金字塔：归因、交互和外部标尺

单一 eval 层无法同时兼顾成本、归因和真实性。我最终形成了三层金字塔：

| 层 | 测什么 | 节奏 | 当前状态 |
|---|---|---|---|
| L1 | 单个模型决策面 | 改到该面时运行；cassette 可重放 | 8 组 consumer |
| L2 | 自有分布的完整小任务 | 改 prompt、loop 或多模块交互时 | **尚未建设** |
| L3 | 外部真实 benchmark | 里程碑、发版 | SWE-bench Lite 300 题 |

L1 负责归因：到底是 tool description、skill trigger 还是 error feedback 出了问题。
L3 负责外部可比性和未预料的全链路交互，但成本高，最终分数本身不能解释原因。

L2 应该由 10 到 30 个自己控制的迷你仓库任务组成，使用测试通过、文件内容和 turn cap 等
硬 oracle。它测的是 L1 看不见的模块相互作用，又比 SWE-bench 更贴项目真实用途。

这仍然是当前系统最重要的缺口。L1 已经丰富，L3 也跑过全量，但缺少中间层意味着日常改
compaction、memory 和 loop 策略时，要么只看局部探针，要么付出完整 benchmark 成本。


## 九、SWE-bench：分数是尺，records 才是显微镜

我用 shipped `oh` CLI 跑完 SWE-bench Lite 300 题，不是为了单独得到一个榜单数字，而是
为了让完整 harness 在冻结任务和隐藏测试下接受外部判定。

Adapter 做了几项保证：

- 通过 subprocess 调真实 CLI，而不是绕过用户入口 import engine；
- 每题使用 fresh checkout，关闭本机 memory、snapshot、skills 等污染源；
- 隐藏 `patch`、`test_patch`、FAIL_TO_PASS、PASS_TO_PASS 和 hints，防止 oracle 泄漏；
- 使用 `git add -A && git diff --cached`，确保新文件也进入 patch；
- 同时输出标准 `predictions.jsonl` 和包含 turns、usage、duration、status 的
  `records.jsonl`。

这里最关键的设计不是 predictions，而是双轨：分数告诉我“对不对”，records 让我追问
“为什么”。没有外部 verdict，trace 只是过程日志；没有 trace，170/300 只是无法归因的标量。

### 实验条件本身也会背叛你

全量战役中，DashScope 曾在中途把 thinking 默认翻转。相同请求的最小 A/B 显示：默认
thinking 约 48 秒、9,176 reasoning 字符；显式关闭后约 1.4 秒、22 tokens。长 agent loop
因此从正常执行变成每轮分钟级，900 秒 timeout 根本装不下。

这次事故推翻了此前对若干题“模型不会收敛”的归因。固定 `enable_thinking=false` 后，
曾连续 timeout 的 `django-11019` 在 193 秒、28 turns 内完成。结论不是模型突然变强，
而是先前实验条件没有被钉死。

战役最终暴露并推动修复了 5 个 harness 缺口：版本漂移、子进程配置源漂移、缺失
`--max-turns`、stream 中断未被 retry，以及缺少 provider-specific request passthrough。
这些都不是最终 benchmark 分数直接告诉我的，而是运行记录与判别实验给出的。

### 官方判卷坏了，也要有办法验证判卷通道

官方 hosted evaluator 一度把 300 题全部报成 failed。为了区分“我的 patch 坏”还是“判卷
服务坏”，我提交了官方 gold patch 作为 probe；gold patch 同样失败，才把问题定位到服务端。
随后在阿里云 ECS 自建官方 SWE-bench harness，处理磁盘、OOM、swap 与报告覆盖问题，最终
得到 `170/300 resolved = 56.7%`。

Gold patch probe 是这段经历里最重要的实验动作之一：当测量结果异常时，先用已知正确输入
验证测量装置，而不是立刻解释被测系统。

### 收紧失败归因

最终受控条件下，97 个 unresolved 中有 86 个完成 harness 流程但 patch 未通过隐藏测试，
11 个撞到 turn cap；records 中没有记录到 runtime crash、权限误拦等**硬 harness 失败**。

这能支持的 claim 是：“最终运行里没有观察到 harness 硬失败，主要瓶颈表现为 patch 正确性
和收敛。”它不能严格推出“97 个失败 100% 都由模型造成”。Prompt、工具可见性、缺少 sandbox
验证等 harness 选择仍可能影响模型为什么写错，只是这些因果没有被当前分类直接识别。

同样，resolved 题 turn 中位数 11、completed-but-unresolved 中位数 13，只能说明 turn 数对
正确性的区分度很低，不能单独证明模型或 harness 的全部责任。它最直接支持的是：工作很久、
自然停止和自称完成，都不是 completion evidence。


## 十、失败如何真正进入飞轮

Eval 的价值不在于存一排稳定分数，而在于失败是否改变生产系统。

### 从 benchmark 死亡链到 20 行探针

`astropy-14182` 在真实战役中出现过一条死亡链：模型调用 Bash 跑测试，被 headless permission
拒绝后继续绕圈，最后撞上 turn cap。

这个失败后来被沉成 `error_feedback` 的单步 case：预先种植相同 permission-denied 历史，
检查下一步是否原样重发、是否仍有后续动作。N=4 中模型有 1 次原样重发 `pytest -q`，真实
失败形态在一个廉价探针里被复现。它没有被删掉，而是成为观察项。

### Prompt 改进也要经过 ratchet

`skill_trigger` 基线有一个委派吸引子：模型看到匹配 skill，却直接 SpawnAgent 或直答，不先
LoadSkill。两版目录引导语都治好了这个问题，却各出现 1/4 的新失误：把 skill slug 当成
可调用工具名。

预先规则最初规定“任一稳定绿 case 一次破绿就回滚”，所以两版都被回滚。复盘发现单次破绿
与既有随机波动同量级，于是把规则校准为“稳定破坏需要 N=4 中至少失败两次”。按新规则复核，
第二版恢复进入生产，稳定地板从 6/9 提升到 7/9。

这不是为通过而改规则。原始失败、误杀、规则修订和新 bar 全部保留。真正的飞轮是：

```text
dogfood / benchmark failure
        -> 归到具体决策面
        -> 沉成带 oracle 的 case
        -> 改 production subject
        -> N 次稳定性画像
        -> 守回归并抬高 ratchet
```

Dataset 不应该靠想象批量扩充。每个已经归因的真实失败，才是概率系统里“bug 变 regression
test”的对应物。


## 十一、当前系统仍然没有解决什么

深度阅读当前实现后，我会主动保留以下边界：

1. **L2 任务级 eval 缺失。** 这是最大的结构缺口。
2. **L1 数据集仍然小且以合成为主。** 真实失败已开始进入，但还不是用户分布代表集。
3. **Cassette freshness 没有自动保证。** Prompt hash 不在 key 中，replay 绿可能只是旧录音绿。
4. **共享 substrate 只部分统一。** 最早的 `Sample`、`Scorer` 和 `runner` 仍与 focus_state
   output 类型绑定；后续 consumer 各自实现 typed sample/loader/runner，只复用 `Score`、
   cassette 与方法模式。它避免了过早 generic，但“surface-agnostic substrate”尚未完全兑现。
5. **Results persistence 没有统一覆盖所有 consumer。** Focus state 和 memory decision 使用
   version-stamped JSONL；较新的 eval 主要保留 cassette 与手工重定向的画像文本。
6. **没有可靠的 cross-model 排名能力。** Reference model policy 是回归基线，不是排行榜。
7. **Sub-agent 和 decomposer eval 被主动 park。** 不是遗忘，而是等待热路径中的真实失败；
   覆盖率不是目标，load-bearing 风险才是。

把这些写出来不会削弱项目。相反，它说明我知道现有证据能支持到哪里，也知道下一单位投入
最应该解决什么。


## 十二、我最终形成的八条原则

1. **先写 capability claim，再写 case。** 不知道要证明什么，就不该开始测。
2. **覆盖按决策面计算，不按 case 数量计算。**
3. **能硬绝不软。** 优先 `=`、不变量和存在性检查，最后才用 LLM judge。
4. **Case 是预先注册的可证伪假设，不是成功展示。**
5. **概率 gate 必须来自稳定性画像。** 一次红或一次绿都不能直接立法。
6. **Replay 管成本与录制回归，live 才管当前模型真实性。**
7. **分数必须配 trace。** 尺告诉我变没变，显微镜告诉我为什么。
8. **失败必须沉成 case。** 否则 dogfood 和 benchmark 只是一次性体验，不是改进飞轮。


## 结论

Harness 本身不可求导。System prompt、工具描述、权限反馈、context 策略和 loop control 共同
影响结果，但没有梯度告诉我该改哪一行。

Eval 提供的是有限差分能力：冻结模型、dataset、oracle 和实验条件，只改变一个 harness
变量，再读取行为差异。它不保证每次归因都正确，但让“我觉得这个 prompt 更好”升级成一个
可以被重复、挑战和修正的工程判断。

这也是 Eval 决定项目是工程系统还是个人 demo 的原因。Demo 证明“它成功过”；工程系统必须
继续证明：成功发生在什么条件下、失败属于哪个决策面、测量装置是否可信，以及下一次改动
有没有真实提高系统能力。


## 项目证据

- [Eval first-principles](https://github.com/maisieyang/open-harness/blob/main/docs/ideas/eval-first-principles.md)
- [D31：Eval substrate](https://github.com/maisieyang/open-harness/blob/main/decisions/31-eval-substrate-boundary.md)
- [D35：Eval coverage map](https://github.com/maisieyang/open-harness/blob/main/decisions/35-eval-coverage-map.md)
- [D41：Eval 系统化与金字塔](https://github.com/maisieyang/open-harness/blob/main/decisions/41-eval-systematization.md)
- [D45：Secondary-pass evals](https://github.com/maisieyang/open-harness/blob/main/decisions/45-secondary-pass-evals.md)
- [Tool choice dataset card](https://github.com/maisieyang/open-harness/blob/main/evals/tool_choice/dataset_card.md)
- [Skill trigger dataset card](https://github.com/maisieyang/open-harness/blob/main/evals/skill_trigger/dataset_card.md)
- [Error feedback dataset card](https://github.com/maisieyang/open-harness/blob/main/evals/error_feedback/dataset_card.md)
- [SWE-bench adapter boundary](https://github.com/maisieyang/open-harness/blob/main/decisions/40-swebench-adapter-boundary.md)
- [SWE-bench RUNLOG](https://github.com/maisieyang/open-harness/blob/main/benchmarks/swebench/RUNLOG.md)
- [SWE-bench failure taxonomy](https://github.com/maisieyang/open-harness/blob/main/benchmarks/swebench/TAXONOMY.md)
