---
name: harness-dev
description: 模块开发主循环。轻量协调者：加载上下文后调用 harness-onboard（需求分类+影响面+流程确认），再调用 harness-roles（帽子系统多角色执行），最后沉淀上下文。通常由 .harness/AGENTS.md 自动激活，也可通过 /harness-dev 显式调用。
---

# harness-dev：开发主循环

## 激活方式

**自动激活（推荐）**：当前目录存在 `.harness/AGENTS.md` 时，Claude Code 在对话开始时自动读取，用户描述开发需求后本 skill 自动接管。

**显式调用**：用户执行 `/harness-dev` 强制进入开发循环。

---

## Step 0：版本检查（非阻塞，每次对话开始时）

读取 `.harness/framework/version`，与 `~/.forge/framework/version` 对比：

- 版本相同 → 静默，继续
- 当前低于最新 → 旁路提示，不阻断开发：

```
💡 Harness 框架有新版本 {X.Y.Z}（当前 {X.Y.W}）
   要现在升级吗？(y / 稍后 / 跳过)
```

- `~/.forge/` 不存在 → 静默跳过

---

## Step 1：加载模块上下文

读取以下文件（全部加载到工作上下文）：
1. `.harness/context/module.md`
2. `.harness/context/deps.md`
3. `.harness/context/arch.md`
4. `.harness/context/constraints.md`
5. `.harness/workflow/dev.md`
6. `.harness/workflow/checklist.md`

**如果 `.harness/` 不存在** → 提示用户先运行 `/harness-init`，终止。

---

## Step 2：调用 harness-onboard

将以下信息传入 harness-onboard：
- 用户的原始需求描述
- 已加载的 context 文件内容
- `workflow/dev.md` 的完整内容

harness-onboard 返回：确认后的流程 JSON（`resolved_slots` + `role_config` + `work_type` 等，见 harness-onboard 规范）

如果 harness-onboard 失败，告知失败原因，等待用户指示（跳过 / 重试）。

---

## Step 3：调用 harness-roles

将 harness-onboard 返回的流程 JSON 原样传入 harness-roles。

harness-roles 负责按 `resolved_slots` 顺序逐角色执行，管理预算，处理里程碑节点。

---

## Step 4：上下文沉淀

所有角色执行完成后，检测是否产生新上下文并提示用户：

```
📝 本次开发产生了以下新上下文，建议沉淀：

  arch.md 新增建议：
    "{日期}：{推断的架构决策描述}"

  constraints.md 新增建议：
    "{推断的新约束}"

要现在更新吗？(y / 不用)
```

用户确认后，用 Edit 工具追加到对应文件末尾。

---

## 错误处理

| 情况 | 行为 |
|-----|-----|
| `.harness/` 不存在 | 提示运行 `/harness-init`，终止 |
| `workflow/dev.md` 缺失 | 使用内置默认配置（见下方），提示用户补全 |
| harness-onboard 调用失败 | 告知失败原因，等待用户指示（跳过 / 重试）|
| harness-roles 调用失败 | 告知失败的角色名和原因，等待用户指示 |

**内置默认配置（`workflow/dev.md` 缺失时使用）：**

```yaml
roles:
  planner:   { model: opus,   budget: $0.50 }
  builder:   { model: sonnet, budget: $2.00 }
  critic:    { model: sonnet, budget: $0.50 }
  finalizer: { model: haiku,  budget: $0.20 }
overdraft: ask
slots:
  - { name: plan,      skill: superpowers:brainstorming,               role: planner,   milestone: true }
  - { name: implement, skill: superpowers:subagent-driven-development,  role: builder,   milestone: true }
  - { name: review,    skill: harness-review,                          role: critic }
  - { name: finish,    skill: superpowers:finishing-a-development-branch, role: finalizer, milestone: true }
rules: []
```
