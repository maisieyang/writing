# 扩展 Coding Agent，不要扩展 Engine：我实现 Harness Plugin 的过程

> 写于 2026-08-04
> 这是我在 [build-my-own-harness](https://github.com/maisieyang/build-my-own-harness)
> 中实现 Skills、Commands、MCP、ModeBundle 与 Plugin，并用
> [finance-skills](https://github.com/maisieyang/finance-skills) 做兼容性 dogfood
> 之后的工程复盘。


## 引子：新能力应该进入系统的哪一层

Coding Agent 做到一定阶段后，扩展需求会从四面八方出现：

- 增加一个外部工具；
- 加载一套领域方法；
- 提供一个可复用的工作流入口；
- 切换一组 prompt、tools、permissions 和 hooks；
- 把这些东西作为一个完整产品分发给另一个团队。

最直接的做法，是每出现一种能力就在 engine 里加一个分支：识别 plugin、解析 skill、
调 MCP、切 mode、改 permission。短期看每个功能都能跑，长期却会得到多套彼此不一致的
dispatch、权限和恢复路径。

我在 OpenHarness 里走的是另一条路：先把能力拆成少数 runtime primitives，再让 plugin
只负责发现、翻译、命名和分发。一个外部能力进入运行时之后，engine 不再关心它来自
项目文件、用户目录、OpenHarness plugin，还是 Claude Code plugin。

这条支线最终形成了一个判断：

> Plugin 不是第二套 runtime。Plugin 是 capability distribution layer：它把外部能力
> 编译成 harness 已经理解的 primitives；各类能力继续复用原有的执行、策略、观测与
> 状态管理路径。


## 一、先把五种“扩展”拆开

“Plugin 能扩展 Agent”这句话信息量太低。真正进入系统的东西并不相同：

| 能力 | 扩展什么 | 进入系统的位置 | 谁决定使用 |
|---|---|---|---|
| Command | 用户输入模板 | LLM 调用前的 prompt transformation | 用户 |
| Skill | 领域知识与方法 | catalog + `LoadSkill` tool result | 模型或用户 |
| MCP | 外部动作 | `BaseTool` adapter + tool registry | 模型 |
| ModeBundle | prompt、tool catalog、permission、hooks 的组合 | resolved `QueryContext` | 用户触发 |
| Hook | 工具生命周期策略 | Pre/Post tool event chain | harness |

这些能力有不同的语义，不应该被压成一个万能 plugin callback。

### Command：在 LLM 之前消失

Command 是 markdown prompt template。用户输入 `/review last commit`，CLI 查找模板、替换
`{args}`，最后交给 engine 的只是普通 user message。从 `run_query` 的视角看，command
从未存在。

它不应该触发 permission，也不应该成为模型工具。它是 user-facing input transformation。

### Skill：只在需要时加载正文

Skill 的名字和 description 常驻 system prompt，正文不预加载。模型判断相关时调用
`LoadSkill(name=...)`，skill body 作为标准 `tool_result` 进入 messages。

这使领域知识服从普通 tool evidence 的生命周期：可以进入 history、snapshot 和
compaction，而不是被永久焊进 system prompt。模型看到 catalog 后自己选择，harness
不做关键词匹配或隐藏的 relevance ranking。

### MCP：外部工具也只是 `BaseTool`

MCP server 暴露的 tool 先被 adapter 翻译成 `BaseTool`，再注册进同一个 ToolRegistry。
engine、hook executor 和 permission checker 都不需要 `if McpTool` 分支。

MCP adapter 负责提前声明 trust source：未受信任 server 即使自称 read-only，也会被强制
走严格权限路径。权限层消费统一的 `is_read_only`，不负责理解 MCP transport。

### ModeBundle：组装 Context，不修改 Engine

ModeBundle 可以同时声明 system prompt、tool whitelist、deny paths 和 named hooks。
它不是一种新执行模式，而是一个 `QueryContext` factory：CLI 在调用 engine 前把这些
primitive 组装好，engine 收到的仍然只是普通 context。

这一层的原则是：**组合已有契约，不把组合概念泄漏给被组合的层。**


## 二、Plugin 的职责是 fan-out，不是 dispatch

当 Commands、Skills、Bundles、Hooks 和 MCP 都已经有独立入口后，用户安装一个领域能力
仍然要复制多个文件、修改 MCP 配置，再分别理解五套目录约定。

Plugin 解决的是分发问题：一个 manifest 声明多个 component，loader 在 bootstrap 阶段
把它们 fan out 到既有 registration path。

```text
plugin directory
      |
      v
PluginManifest
      |
      +--> namespaced Command --> CommandStore
      +--> namespaced Skill   --> SkillStore
      +--> namespaced Bundle  --> BundleStore
      +--> namespaced Hook    --> HookRegistry
      +--> namespaced MCP     --> McpClientPool / ToolRegistry
                                      |
                                      v
                              existing agent engine
```

[`PluginLoader.fan_out`](https://github.com/maisieyang/build-my-own-harness/blob/main/src/openharness/plugins/loader.py)
只做 component parse、namespace 和 catalog merge。CLI 用 `LayeredStore` 把 plugin catalog
叠在原有 store 上，consumer 继续调用同一个 `get()` / `discover()` 接口。

这条边界在 Phase 9 被写成一条强约束：Plugin 不允许增加新的 dispatch path。接入后以下
模块必须不感知 plugin：

- `engine/query.py`；
- permissions；
- hook executor；
- commands、skills、bundles 的 consumer；
- compaction 与 protocols。

这不是为了追求漂亮的零 diff。它验证的是底层抽象能否承受新的分发方式。如果每种 plugin
来源都要修改 engine，所谓 extension system 只是把条件分支搬了家。


## 三、运行时应该忘记能力来自哪里

OpenHarness 最初有自己的 `manifest.yaml`：可以声明 commands、skills、bundles、hooks
和 stdio MCP servers。后来我希望直接加载 Claude Code plugin 的目录结构：

```text
credit-report-reviewer/
  .claude-plugin/plugin.json
  skills/
    parse-credit-report/SKILL.md
    apply-credit-rules/SKILL.md
    cross-verify-application/SKILL.md
    draft-credit-finding/SKILL.md
```

一种做法是增加 `CCPluginManifest`、`CCPluginLoader`，然后让所有下游接收
`PluginManifest | CCPluginManifest`。这会把来源格式传播到整个系统。

我最终扩展了同一个 loader：

1. 目录包含 `.claude-plugin/plugin.json` 时走 CC parser；
2. 否则包含 `manifest.yaml` 时走 OH parser；
3. 两条路径都返回同一个 `PluginManifest`；
4. 下游 fan-out 不接收 `source_format`，也不按来源分支；
5. format 只保留在 introspection 和 observability 中。

[`parse_cc_plugin`](https://github.com/maisieyang/build-my-own-harness/blob/main/src/openharness/plugins/model.py)
把 CC 的 `author.name` 投影到 flat author，扫描 `skills/*/SKILL.md`，不支持的字段映射为
空值。`oh plugins list` 可以显示 `FORMAT=cc|oh`，但 SkillStore 和 engine 永远看不到
这个字段。

这就是 translation boundary：**来源差异在 bootstrap 收敛，运行时只消费规范化后的
capability。**


## 四、Namespace 的一次不漂亮但正确的取舍

Plugin 内部 component 必须 namespaced，否则两个 plugin 都声明 `deploy` 或
`parse-report` 时会冲突。

我最初想使用更自然的 `plugin:component`。实现前检查发现，Commands、Skills、Bundles、
Hooks 和 MCP 的既有 name regex 都不接受冒号。

当时有三条路：

1. 同时修改五个 subsystem 的 name contract；
2. 内部存 `__`，展示时翻译成 `:`；
3. 从存储、LLM catalog 到用户输入都统一使用 `__`。

第二条看起来最优雅，实际会让每一个 renderer、resolver 和 tool input parser 都理解
plugin translation。plugin-aware logic 会从 loader 渗透到所有消费层。

我选择了第三条：`credit-report-reviewer__parse-credit-report`。它不够好看，但保持了
五个 subsystem 和 engine 零修改，边界也只有一种真实表示。

这个取舍让我更警惕“只在 UI 上做一次翻译”这句话。只要一个名字会被用户输入、模型输出、
storage lookup 和 observability 同时消费，cosmetic translation 就很可能变成跨层协议。


## 五、用户触发 Skill 与模型调用 Tool 不是同一种动作

Skill 原本只支持模型自主调用 `LoadSkill`。为了兼容 `/<skill-name> args` 的交互，我增加了
一条 user-triggered 路径。

resolver 的优先级是：

```text
built-in command -> user Command -> Skill -> unknown
```

命中 Skill 后，REPL 不重新实现 skill injection，而是合成一个标准消息 envelope：

```text
[assistant] tool_use: LoadSkill(name=<skill>)
[user]      tool_result: <skill body>
[user]      text: <args>
```

skill body 因此仍然以 tool result 身份进入 conversation。snapshot 和后续 compaction 看到的
是普通 protocol blocks，不需要 `if plugin_skill` 分支。`synth_` tool-use ID 与
`slash_skill_invoked(synthetic=true)` event 则保留来源审计。

但这里有一个重要分歧：这次 `LoadSkill` 不是模型提出的 action，而是用户在 UI 明确触发的
action。合成 envelope 不执行 `LoadSkillTool`，也不经过 Pre/PostToolUse 和 permission
chain。

我的判断是：

> 两种事件可以共享 protocol shape，但不能因为字节相似就假设 policy semantics 相同。

Hooks 和 permissions 用来约束模型动作；用户直接选择 skill，更接近把一段 expert guidance
粘贴进对话。它仍然需要单独的 audit event，但不需要伪装成一次被模型提议的 tool execution。


## 六、兼容格式，不等于模拟整个外部系统

在设计 CC plugin parser 时，我最初把 `.mcp.json` 也列进范围，理由是双方都在声明 MCP
server，看起来只差 JSON 到 dataclass 的转换。

实施前我重新审计 MCP 层，发现这个判断是错的：

- OpenHarness 当时只支持 stdio transport，配置要求非空 `command`；
- finance-skills 的 `.mcp.json` 使用 HTTP + OAuth2，只有 URL 和 auth；
- 即使字段勉强解析成功，当前 `McpClientPool` 也没有可以执行它的 transport。

这不是 schema mapping，而是 capability mismatch。

我在代码落地前撤回了 `.mcp.json` 支持。CC plugin 仍然可以被发现并加载 Skills，但
`mcp_servers` 明确为空；`oh plugins list` 对带有 3 个 HTTP server 的
`credit-bureau-connectors` 显示 `MCP_SERVERS=0`。

```text
NAME                      FORMAT  VERSION  SKILLS  MCP_SERVERS
credit-bureau-connectors  cc      0.1.0    0       0
credit-report-reviewer    cc      0.1.0    4       0
```

这比“尽量解析、逐条 warning、最终部分可用”更诚实。用户看到的是系统实际能执行的能力，
不是磁盘上存在多少配置文件。

这次 reversal 留给我的方法是：检查兼容性不能只对字段表，还要逐层对齐：

| 层 | 要问的问题 |
|---|---|
| Syntax | 文件能否被解析？ |
| Schema | 字段能否映射？ |
| Semantics | 两边字段表达的是同一件事吗？ |
| Transport | 当前 runtime 能否建立连接并执行？ |
| Trust | 凭据、授权和副作用边界是否等价？ |

只有前两层通过，不叫 capability compatibility。


## 七、Finance Skills Dogfood：证明“装进来”还不够

我用一个包含 4 个信审 Skills 的真实 Claude Code plugin 做端到端测试。整个 plugin 目录
复制进 `~/.openharness/plugins/` 后，没有重命名 SKILL.md，也没有改写 schema：

```bash
cp -r credit-report-reviewer ~/.openharness/plugins/credit-report-reviewer
oh chat --enable-plugins
```

`/skills` 显示 4 个 namespaced skills；直接输入：

```text
/credit-report-reviewer__parse-credit-report 申请号12345
```

模型不只识别了被调用的征信解析 Skill，还根据 catalog 中另外三个 Skill 的名字与 description，
组合出了 parse -> cross-verify -> apply-rules -> draft-finding 的完整工作流，并明确指出
当前缺少 `pboc_credit` MCP 数据源。

这个结果验证了三件事：

1. CC parser 的输出确实进入了既有 SkillStore；
2. namespaced Skill 复用了既有 catalog 和 slash-trigger path；
3. plugin 作为一组能力出现后，模型可以看到它们之间的工作流关系。

更重要的证据是：`engine/slash_skill.py` 在接入 CC plugin 的整个 phase 保持 zero diff。
前一阶段只接过单文件 `/parse-credit-report`，后一阶段变成
`/credit-report-reviewer__parse-credit-report`，envelope helper 不需要理解 plugin、路径或
namespace。

这比“loader 新增了多少代码”更能说明抽象成立：**后来的能力通过了前一阶段预先留下的
接口，而不是迫使接口追着它变化。**


## 八、Plugin 默认关闭：可扩展不等于默认信任

OpenHarness 自己的 plugin manifest 可以包含 Python hooks。加载 plugin 不只是读取几份
markdown，还可能 import 并执行第三方 Python module。

因此 plugin components 默认不进入运行时，必须显式使用 `--enable-plugins` 或 settings
开关。这个 friction 在第一次 finance-skills dogfood 中真实出现：我复制完 plugin 后直接
运行 `oh chat`，得到 `(no skills installed)`，后来才意识到 plugin gate 仍然关闭。

这个默认值是对的，问题在 onboarding 可见性，而不是应该取消安全边界。

同时，`oh plugins list` 必须在 plugin disabled 时仍然可用。它只执行 read-only discovery，
不 fan-out component，也不 import Python hook module。用户可以先检查安装了什么、格式是什么、
实际识别到多少 Skills/MCP，再决定是否启用。

这体现了两阶段 trust model：

```text
discover / inspect
       -> explicit enable
              -> parse + namespace + fan-out
                     -> existing runtime policies
```

Plugin 扩大能力集合，但不能绕过能力进入 runtime 前的显式信任动作。


## 九、一次真实 Provider 才能暴露的 Envelope Bug

最初的 synthetic skill envelope 有两种形态：有 args 时三条消息；没有 args 时只放
`tool_use + tool_result` 两条消息，然后期待模型自行响应。

单元测试验证了 block 类型、ID 对齐和 body 原样保留，全部通过。两轮 dogfood 也都通过，
因为我每次都输入了 `申请号12345`，只覆盖三消息路径。

用户后来直接输入不带参数的：

```text
/credit-report-reviewer__parse-credit-report
```

qwen3.7-max 的 thinking API 返回 400，要求回传此前并不存在的 `reasoning_content`。合成的
assistant `tool_use` 没有真实 thinking turn，二消息形态却让 provider 把它解释成需要继续
同一 reasoning chain 的请求。

修复没有增加 Qwen-specific branch。我把 envelope 统一成恒定三消息：args 为空时也追加
一个 user TextBlock，建立明确的新 turn boundary。

第一版 placeholder 是：

```text
Please apply this skill now.
```

协议错误消失了，但模型把它理解成“立即寻找输入并执行”，发起十多次 Read/Bash/Find，试图
从 filesystem 找到并不存在的征信数据。于是 placeholder 又改成：

```text
What input do you need to apply this skill?
Wait for me to provide it; do not explore the filesystem to find it yourself.
```

这次失败给了我两层教训：

1. schema-level unit test 不等于 provider-level protocol compatibility；
2. 修复协议形态之后，补位文本本身仍然会改变 Agent 行为。

一个 extension envelope 同时是 protocol object 和 behavioral prompt，两层都要 dogfood。


## 十、Eval 测的不是“Skill 写得好不好”

格式兼容和端到端 dogfood 证明路径能走通，但模型是否会在合适时机加载正确 Skill，仍然是
概率问题。

我为 production catalog 与 `LoadSkill` description 建了一个 9-case eval：

- 正面触发 2 个；
- 相邻金融 Skill 辨析 2 个；
- 无关任务 restraint 2 个；
- unknown slug 后自纠 1 个；
- 连字符 slug 精确性 2 个。

这里的 oracle 很硬，不需要另一个 LLM judge：该调时是否出现 `LoadSkill`，不该调时是否
保持克制，首个 call 的 `name` 是否与目标 slug 精确相等。

参考模型 qwen-max 的当前 gate 是 `>=7/9`，且 7 个稳定 case 必须全部通过；4 次画像是
8/9、9/9、8/9、8/9。这个结果不被解释成 Skill 系统“接近满分”，它只守住单步 trigger、
discrimination、restraint 与 slug fidelity。

Eval 还暴露过一个有意思的交换：强化 prompt 中“必须先调用 LoadSkill”可以治好模型直接
回答或委派的倾向，却偶尔诱发模型把 skill slug 当成真实 tool name。突出一种能力，也会
增强另一种幻觉的吸引力。

这说明 extension quality 不能只看“触发率越高越好”。正确指标至少同时包含：

- 该触发时触发；
- 不该触发时克制；
- 选择正确能力；
- 出错后能否通过目录反馈自纠。


## 十一、我现在怎样判断一个 Extension Abstraction 是否成立

做完这条线后，我不再用“接口看起来通用”判断抽象质量，而看它能否产生可验证的预测。

### 1. 新来源接入后，consumer 是否零修改

CC plugin 接入前，我预测 synthetic envelope 和 SkillStore consumer 不需要修改；实际成立。
如果预测失败，就应该重新检查 abstraction，而不是直接补一个 `if source == "cc"`。

### 2. Provenance 是否在正确边界消失

CLI introspection 可以显示 cc/oh；observability 可以记录 source format；runtime Skill 不应该
携带“我是 CC Skill”并要求 engine 特殊处理。

### 3. Unsupported capability 是否被诚实删除

HTTP MCP、declarative agents、marketplace 等尚未实现的能力，不能因为 plugin 被成功发现
就暗示已经支持。磁盘存在不等于 runtime 可用。

### 4. Policy 是否由动作语义决定，而不是由 schema 决定

用户直接 `/skill` 与模型自主 `LoadSkill` 可以共享 tool envelope，但 hooks/permissions
策略不同；MCP adapter 与 local tool 共享 BaseTool，但 trust source 不同。

### 5. Abstraction 是否能被失败推翻

`.mcp.json` reversal 说明 compatibility 假设可以在写代码前被协议审计推翻；empty-args bug
说明 unit test 不能替代真实 provider。一个不能被反证的“通用抽象”通常只是叙事。


## 十二、当前边界

这套 Plugin 体系仍然有明确限制：

- CC plugin 当前只映射 manifest identity 与 Skills；`.mcp.json` HTTP/OAuth2 不加载；
- `agents/<name>.md` declarative sub-agent 尚未进入 runtime；
- 不扫描 Claude Code 自己的 plugin root，也不实现 marketplace fan-out；
- Python hooks 在主进程内运行，没有 plugin subprocess isolation 或签名验证；
- plugin catalog bootstrap-frozen，没有 mid-session hot reload；
- `__` namespace 保持协议简单，但用户体验仍不够自然；
- skill-trigger eval 只测单步选择，不评价 skill body 后续执行质量。

这些边界决定了我不会把项目描述成“兼容 Claude Code plugins”。更准确的说法是：

> OpenHarness 建立了一个 plugin-neutral capability substrate，并验证了 Claude Code 格式的
> Skills 可以通过翻译进入其中；不兼容的 transport 和 component 被明确留在边界外。


## 结论

Harness + Plugin 这条线最终让我把 Model、Harness 和 Plugin 的关系分得更清楚：

- Model 选择和编排能力；
- Harness 定义工具、证据、授权、hooks、context 与执行契约；
- Plugin 把领域能力封装并翻译到这些契约中。

Plugin 的价值不在于让 engine 认识更多 extension type，而在于让 engine **不用认识**它们。
一个新能力在 bootstrap 时被编译成既有 primitives，此后由其动作语义决定走 Command、
Skill、Tool 或 Hook 原有的执行与策略路径；plugin 来源不再创造第二套 permission、
observability、compaction 或 completion control。

对我来说，这才是可持续扩展的判据：

> 能力可以持续增加，运行时的控制路径却不随能力数量线性增长。
