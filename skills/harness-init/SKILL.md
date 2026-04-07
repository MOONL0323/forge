---
name: harness-init
description: 在当前模块目录下初始化 Harness 框架。扫描代码结构、预填上下文文件、引导开发者逐节审核确认，最终写入 .harness/ 目录。适用于 cmd/、apps/、pkg/ 下的任意模块。
---

# harness-init：初始化 Harness

## 触发条件

用户执行 `/harness-init` 或明确说"帮我初始化 harness"时调用本 skill。

## 执行流程

### Phase 1：自动扫描（不打扰用户，静默完成）

扫描当前目录，收集以下信息：

**1. 判断模块类型**
- 路径含 `cmd/` → 类型 = `cmd`（后台服务）
- 路径含 `apps/` → 类型 = `app`（Web 服务）
- 路径含 `pkg/` → 类型 = `pkg`（共享包）
- 其他 → 询问用户

**2. 读取现有文档**（按优先级）
- `README.md`（当前目录）
- `.roo/rules/` 下所有 `.md` 文件
- `.cospec/docs/` 下所有 `.md` 文件

**3. 分析代码结构**
- 读取所有 `.go` 文件的 `import` 块，提取 `pkg/` 依赖列表
- 读取 `git log --oneline -20`，了解近期变更高频区域

**4. 查找已有 Harness**
- 检查当前目录是否已有 `.harness/`
- 若有 → 进入增量补全模式（Phase 2 仅处理 TODO 节点）
- 若无 → 进入全量初始化模式

**5. 查找依赖包的 Harness**
- 对每个 `pkg/` 依赖，检查 `{monorepo_root}/pkg/{name}/.harness/contract.md` 是否存在
- 存在则读取，用于预填 deps.md

**6. 查找同类模块的 Harness**（辅助推断）
- 扫描同级目录中其他 cmd/app 模块的 `.harness/context/module.md`
- 用于参考推断当前模块的职责描述和约束风格

**7. 输出扫描摘要**

```
🔍 扫描完成：
  模块类型：{cmd/app/pkg}
  发现文档：README.md ✓ / .roo/rules ✓ / .cospec/docs ✓
  pkg 依赖：{列表，注明哪些有 Harness、哪些没有}
  近期高频变更：{top 3 文件}
  模式：{全量初始化 / 增量补全（发现 N 个 TODO）}

开始逐节确认，你可以：
  · 直接说「好」接受草稿
  · 说出修改意见，我来改
  · 说「跳过」留 TODO 占位，后续补充
```

---

### Phase 2：对话式逐节审核

#### 全量初始化模式

按以下顺序逐节展示草稿，每节确认后再进入下一节。

**节 1：module.md（模块身份）**

根据扫描结果生成草稿，格式：

```
📄 module.md 草稿：

  模块名：{推断的模块名}
  类型：{cmd/app/pkg}（推断来源：目录路径）
  负责人：{从 git log 推断的主要提交者}
  职责：{从 README 提取的一句话描述，或从目录结构推断}
  核心概念：
    - {从代码/README 提取的关键术语 1}
    - {从代码/README 提取的关键术语 2}
    （低置信度内容标注 ⚠️ 推断，请验证）

这样描述准确吗？
```

**节 2：deps.md（依赖关系）**

```
📄 deps.md 草稿：

  依赖的 pkg 包：
  {对每个 import 的 pkg/：
    - pkg/{name}（有/无 Harness）
      用途：{从 contract.md 读取描述，或标注 ⚠️ 从代码推断}
      关键接口：{列出调用的函数，从代码 grep 结果整理}}

  外部服务依赖：
    {从代码扫描 mongo/redis/kafka 关键词推断}

这样准确吗？
```

**节 3：arch.md（架构决策）**

```
📄 arch.md 草稿：

  根据 git log 和代码结构，我推断了以下可能的架构决策：

  {如果有明显的设计模式，如 Provider 接口、插件系统等，生成一条 ADR 草稿}
  {如果推断不出，生成一条空的 ADR 模板并标注 TODO}

这些推断准确吗？或者有哪些重要的架构决策需要记录？
```

**节 4：constraints.md（规范约束）**

```
📄 constraints.md 草稿：

  从 .roo/rules/ 和 .cospec/docs/ 继承的约束：
    {列出从现有文档提取的相关规范}

  从代码推断的约束：
    高危区域：{近30天变更超过5次的文件，标注为高频变更}

  待补充（TODO）：
    - 禁止项：TODO
    - 测试要求：TODO
    - 部署注意：TODO

这些准确吗？有要补充的禁止项或特殊约束吗？
```

**节 5：workflow/dev.md（流程编排）**

```
📄 workflow/dev.md 草稿：

  （展示 dev.md.tmpl 的默认内容）

  默认流程包含：影响面分析 → brainstorming → planning → TDD 编码 → 验证 → 双 Review → PR

  需要定制吗？比如：
    · 跳过某些步骤
    · 添加团队特有的检查环节
    · 修改 Review 配置（adversarial_reviewer）
```

#### 增量补全模式

1. 扫描所有 `.harness/context/*.md` 和 `.harness/overrides/` 中含 `TODO` 的行（精确字符串匹配）
2. 对每个 TODO 行：
   - 展示文件名 + TODO 所在行 + 前后 3 行上下文
   - 以对话方式填充，同全量模式格式
   - 用户确认后替换该 TODO 行，不改动其他内容
3. 所有 TODO 处理完毕 → 提示"增量补全完成"
4. 若没有任何 TODO → 提示"Harness 已完整，如需修改请直接编辑对应文件，或告诉我你想更新哪一节"

---

### Phase 3：写入 & 提交

所有节确认完毕后：

```
✅ 所有内容确认完毕，准备写入：

  .harness/AGENTS.md
  .harness/framework/version          ← 从框架仓库读取
  .harness/context/module.md
  .harness/context/deps.md
  .harness/context/arch.md
  .harness/context/constraints.md
  .harness/workflow/dev.md
  .harness/workflow/checklist.md

要一并 git commit 吗？(y / 不用)
```

写入时，将 AGENTS.md.tmpl 中的占位符替换：
- `{{MODULE_NAME}}` → module.md 中的模块名
- `{{FRAMEWORK_VERSION}}` → 读取 `~/.forge/framework/version`，若不存在则填 `unknown`

**pkg 类型只写入：**
- `.harness/contract.md`（从 templates/pkg/contract.md.tmpl）
- `.harness/constraints.md`（从 templates/pkg/constraints.md.tmpl）
- `.harness/owner.md`（从 templates/pkg/owner.md.tmpl）

---

## 边界情况处理

| 场景 | 处理方式 |
|-----|---------|
| 目录类型无法判断 | 展示选项让用户选择（cmd / app / pkg / 其他）|
| README 缺失 | 完全从代码推断，低置信度内容标注 `⚠️ 推断，请验证` |
| 依赖的 pkg 无 Harness | deps.md 标注 `⚠️ 无 Harness`，建议包主人运行 harness-init |
| `.harness/` 已存在且无 TODO | 提示"Harness 已完整"，询问是否要重新审核某节 |
| 在框架仓库根目录运行 | 提示"请在模块目录下运行，如 cmd/my-module/" |
