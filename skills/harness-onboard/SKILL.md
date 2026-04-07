---
name: harness-onboard
description: 需求分类 + 影响面分析 + 动态流程确认。从用户描述推断工作类型，fetch-first 扫描代码，输出影响面报告，解析 workflow/dev.md 的 rules 动态调整插槽列表，展示流程供用户确认调整，最终输出 resolved_slots JSON 交给 harness-roles 执行。
---

# harness-onboard：引导 + 流程确认

## 输入

由 harness-dev 调用，接收：
- `requirement`：用户原始需求描述
- `context`：已加载的 `.harness/context/` 文件内容（module/deps/arch/constraints）
- `workflow_config`：`workflow/dev.md` 的 YAML 解析结果（roles/overdraft/slots/rules）

---

## Step 1：工作类型推断

从 `requirement` 推断工作类型，**能推断就直接用，推断不出才给用户选择题**：

| 描述关键词 | 推断类型 | 流程影响 |
|-----------|---------|---------|
| "加个功能"、"新增"、"支持"、"实现" | new-feature | 完整流程 |
| "修一下"、"bug"、"报错"、"崩了"、"hotfix"、"fix" | bugfix | 跳过 plan 插槽 |
| "重构"、"整理"、"优化"、"清理" | refactor | 跳过 plan，影响面加风险警告 |
| "新模块"、"新服务"、"新 cmd"、"新 app" | new-module | 先触发 harness-init，再进流程 |
| "新项目" | new-project | 引导项目结构创建 |
| "配置"、"config"、"env"、"环境变量" | config-change | 跳过 plan，跳过 implement，只需 lint + review（极简流程）|
| "文档"、"doc"、"readme"、"注释" | docs-only | 跳过 plan，跳过 implement，跳过 review，只需更新文档 |
| "依赖"、"upgrade"、"bump"、"版本" | dependency-upgrade | plan 前插入兼容性检查插槽 |
| 无法推断 | — | 展示选择题 |

bugfix 和 hotfix 等价处理：两者推断为相同类型，流程影响相同（跳过 plan 插槽）。

**推断不出时展示：**

```
这次是什么类型的工作？
  A. 新功能（完整流程）
  B. Bug 修复（跳过方案设计，直接编码）
  C. 重构/优化
  D. 新模块/新服务
```

---

## Step 2：fetch-first 数据收集

推断工作类型后，按优先级静默扫描，**不向用户提问直到所有来源都已尝试**：

| 优先级 | 来源 | 动作 |
|-------|-----|------|
| 1 | `context`（已加载）| 直接使用 |
| 2 | 相关文件代码 | Grep 需求中的关键词，Read 相关文件 |
| 3 | git log | `git log --oneline -30 -- {相关路径}` |
| 4 | 相关 pkg 的 `.harness/` | 读取 contract.md + constraints.md |
| 5 | 测试文件 | 了解现有行为和边界 |
| 6 | ❓ 向用户提问 | 仅当以上来源均无法回答时 |

**提问原则**：只问"代码里找不到、文档里没有、不知道则无法继续"的内容。禁止模糊提问（如"请描述背景"）。

---

## Step 3：位置确认（按需触发）

当用户描述里没有明确模块，且 context 中无法推断时触发：

```
这个改动要加在哪里？
  A. {模块名1}（{职责描述}）
  B. {模块名2}（{职责描述}）
  C. 两者都要改
  D. 其他（请说明）
```

选项来自 `context/module.md` 和 `context/deps.md` 中的模块列表。

---

## Step 4：影响面分析（强制输出，不可跳过）

```
📊 影响面分析

工作类型：{work_type}（{需求一句话摘要}）

直接修改：
  - {文件路径}（原因：{对应的变更点}）

需要协商（涉及 pkg 公开接口）：
  - pkg/{name}：需要 {新增/修改} {接口名}
    → 包主人：{从 pkg/.harness/owner.md 读取}
    → 已知调用方：{从 pkg/.harness/contract.md 读取}

只读引用，无需改动：
  - {包名}

潜在风险：
  ⚠️ {文件名} 是高频变更文件（近30天 {N} 次提交）
  ⚠️ {接口名} 有 {N} 个调用方，改接口需通知
```

---

## Step 5：应用定制规则（动态插槽修改）

读取 `workflow_config.rules`，逐条解读，修改插槽列表。

**三种操作：**

| 操作 | 效果 | 示例规则 |
|------|------|---------|
| skip | 从列表移除该插槽 | "bugfix 跳过 plan" |
| insert-before | 在目标插槽前插入新条目 | "接口变更前插入 pkg 主人确认" |
| insert-after | 在目标插槽后插入新条目 | "implement 后插入性能测试" |

**动态插入的 checkpoint 格式（无 skill/role，纯人工确认节点）：**

```json
{
  "name": "pkg-owner-confirm",
  "skill": null,
  "role": null,
  "type": "checkpoint",
  "message": "请确认已与 pkg 主人对齐接口设计"
}
```

`type: "checkpoint"` 表示纯人工确认节点，无需调用 skill 或 subagent。`message` 为必填字段，由插入该 checkpoint 的规则决定内容。

所有规则应用后，生成 `resolved_slots` 数组。

---

## Step 6：流程确认

展示最终流程，附预算，等待用户确认或调整：

```
为你准备的流程：
  1. 🎩 Planner   — {plan 插槽的 skill 简称}     ({model}, 预算 ${budget} 估算)
  2. 🔨 Builder   — {implement 插槽的 skill 简称} ({model}, 预算 ${budget} 估算)
  3. 🔍 Critic    — {review 插槽的 skill 简称}    ({model}, 预算 ${budget} 估算)
  4. ✅ Finalizer — {finish 插槽的 skill 简称}    ({model}, 预算 ${budget} 估算)
  估算总预算：${total}

这个流程 OK？还是要调整？
  · 直接说 y 开始
  · "跳过 review"、"Planner 用 Sonnet"、"总预算控制在 $2"
```

**用户调整处理规则：**
- "跳过 {插槽名}" → 从 resolved_slots 移除该条目
- "{角色名} 用 {模型}" → 覆盖该角色的 model
- "总预算 $X" → 按默认比例等比缩减各角色 budget
- "加上 {自定义步骤}" → 询问绑定哪个 skill 和哪个 role，insert-after 最后一个相关插槽

每次调整后重新展示更新后的流程，用户说 y 后进入下一步。

**提示持久化：**

```
已调整（仅本次）：Planner opus → sonnet，Critic 已跳过
如果想永久生效，说"保存这次的配置"
```

用户说"保存这次的配置"时：
1. 将当前 `role_config` 和 `resolved_slots` 写入 `.harness/workflow/dev.md` 的对应字段
2. `rules` 部分保留不动
3. 写入前展示 diff，等用户确认

> **注意**：保存的是 resolved_slots（规则应用后的结果）。如用户意图是永久移除某插槽（非条件性跳过），建议直接编辑 dev.md 文件。

---

## Step 7：输出 JSON 交给 harness-roles

用户说 y 后，输出以下结构（harness-dev 将其原样传入 harness-roles）：

```json
{
  "work_type": "new-feature",
  "requirement": "{用户原始需求}",
  "impact_analysis": "{影响面分析全文}",
  "resolved_slots": [
    { "name": "plan",      "skill": "brainstorming",                       "role": "planner",   "milestone": true },
    { "name": "implement", "skill": "subagent-driven-development",          "role": "builder",   "milestone": true },
    { "name": "review",    "skill": "harness-review",                       "role": "critic",    "milestone": false,
      "review_config": {
        "pass_threshold": { "spec_compliance": 8, "evaluator": 7 },
        "max_iterations": 3
      }
    },
    { "name": "finish",    "skill": "finishing-a-development-branch",        "role": "finalizer", "milestone": true }
  ],
  "role_config": {
    "planner":   { "model": "sonnet", "budget": 0.50 },
    "builder":   { "model": "sonnet", "budget": 2.00 },
    "critic":    { "model": "sonnet", "budget": 0.50 },
    "finalizer": { "model": "haiku",  "budget": 0.20 }
  },
  "overdraft": "ask",
  "session_overrides": "Planner opus → sonnet，Critic 已跳过"
}
```

> `review_config` 告诉 harness-roles：Spec Compliance ≥ 8 且 Evaluator ≥ 7 才算通过。最多迭代 3 次。

---

## Sprint Contract 格式（harness-onboard 输出）

Planner 产出必须符合 Sprint Contract 格式，包含：

```json
{
  "sprint_contract": {
    "sprint": 1,
    "features": [
      {
        "name": "{feature name}",
        "acceptance_criteria": [
          {
            "id": "AC-1",
            "description": "{specific, testable acceptance condition}",
            "verifiable_from": "ui",      // ui | api | cli | log
            "test_method": "Playwright screenshot | curl API | CLI check | log output"
          },
          {
            "id": "AC-2",
            "description": "{another acceptance condition}",
            "verifiable_from": "api",
            "test_method": "curl -X POST /api/order -d '{...}' returns 201"
          }
        ],
        "blackbox_constraint": "✅ All ACs are verifiable from UI/API/CLI. No source code reading required."
      }
    ],
    "sprint_rules": [
      "Max 3 ACs per feature",
      "AC must describe externally observable behavior, not internal implementation",
      "Sprint 1 must deliver one independently testable feature"
    ]
  }
}
```

**Black-box evaluability principle:**
```
❌ Wrong (verifiable from source):
  "verify() returns true when called"

✅ Right (verifiable from UI/API):
  "Click Submit button → page shows success message, console has no ERROR"
  "POST /api/submit returns {status: 'ok'}"
```

Planner（brainstorming skill）在 plan 插槽中必须输出符合此格式的 sprint contract。
未通过 harness-onboard 的 sprint_contract 验证的 plan 不能进入 Builder 阶段。

---

## Review 评分阈值说明

harness-review 使用以下通过标准：

| Reviewer | 维度 | 通过阈值 |
|---------|------|---------|
| Spec Compliance | Overall 平均 | ≥ 8/10 |
| Evaluator | Overall 平均 | ≥ 7/10 |

如果 Overall 处于 6-7 分区，展示警告但不阻断。

如果 Overall < 6，进入迭代改进循环（Generator → Evaluator → 重评分）。3 次迭代后仍失败，停止并汇报用户。
