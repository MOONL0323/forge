---
name: harness-roles
description: 帽子系统执行引擎。接收 harness-onboard 输出的 resolved_slots JSON，逐插槽串行调度新鲜 subagent，追踪 token 消耗换算估算费用，按 overdraft 策略处理超预算，在 milestone 节点等待用户确认。
---

# harness-roles：帽子系统 + 预算管理

## 输入

由 harness-dev 调用，接收 harness-onboard 输出的 JSON（字段说明见 harness-onboard Step 7）：

```json
{
  "work_type": "...",
  "requirement": "...",
  "impact_analysis": "...",
  "resolved_slots": [...],
  "role_config": { ... },
  "overdraft": "ask|allow|deny",
  "session_overrides": "..."
}
```

---

## 执行流程

按 `resolved_slots` 顺序逐插槽执行，不跳过，不改变顺序（顺序由 harness-onboard 已确定）。

---

## 角色调度原则

**每个角色是一个新鲜 subagent**，通过 Claude Code 的 `Agent` 工具派发，不继承主会话历史（防止 context rot）。

**模型选择**：Claude Code Agent 工具当前不支持直接指定模型。通过在 prompt 开头注入角色指令来引导行为风格，但**无法强制约束实际使用的模型**。

> ⚠️ 已知限制：`model` 字段是行为风格指引，不保证实际路由到对应模型。实际模型由 Claude Code 根据任务复杂度自动选择。费用估算基于 `model` 字段计算，若实际路由到更便宜的模型，实际费用会低于估算；若路由到更贵的模型，则可能超支。

**Role prompt injections (English — these are instructions to the model):**

- Planner：`You are the Planner for this development session. Think deeply, reason step by step. Output a complete design document and implementation plan.`
- Builder：`You are the Builder. Focus on efficient implementation. Follow TDD strictly: write the test first, then the minimum code to pass it. Output working, tested code.`
- Critic：`You are the Critic — an external reviewer with no knowledge of the design intent. You see only the diff and the requirement. Judge independently and critically.`
- Finalizer：`You are the Finalizer. Your job is clean and efficient: create the PR and update documentation. Complete the task with minimal fuss.`

**上下文注入规则（每个角色只收到它需要的信息）：**

| 角色 | 收到什么 | 工具白名单 | Turn 限制 |
|------|---------|-----------|---------|
| Planner | 需求 + 影响面分析 + constraints.md | Read, Glob, Grep, WebSearch, Write | 30 |
| Builder | 需求 + Planner 产出的计划 + 相关代码 | Read, Write, Edit, Glob, Grep, Bash | 80 |
| Critic/Evaluator | diff + 需求 + constraints（不给设计方案）| Read, Write, Bash, WebSearch | 40 |
| Finalizer | 需求 + 全部角色产出摘要 | Read, Write, Bash | 20 |
| checkpoint | 无 subagent | — | — |

**MCP 配置（按需启用）**：

| 角色 | MCP Server | 用途 |
|------|-----------|------|
| Evaluator（对抗视角）| `playwright` | 黑盒测试，从不读 src/ 目录 |
| Evaluator | `github` | 查询 CI 状态，评论 PR |
| Planner | `websearch` | 调研技术方案 |

**evaluator 黑盒约束（绝对禁止）**：

Evaluator 在 Playwright MCP 模式下，**禁止读取以下目录的源码**：
```
src/, app/, lib/, components/, pages/, ui/
```
违反此约束的 Review 结果无效，必须重新运行。

---

## 插槽执行循环

对 `resolved_slots` 中的每个插槽：

### 1. 启动提示（非 checkpoint 类型）

```
🎩 {角色帽子} {角色名} 启动  [{slot.name}: {skill 简称}]  ({model} · 预算 ${budget} 估算)
```

### 2. checkpoint 类型处理

若 `slot.type == "checkpoint"`：

```
⏸ 检查点：{slot.message}

确认后继续？(y / 有问题说一下)
```

等待用户输入后进入下一插槽。不消耗预算，不派发 subagent。

### 3. skill 类型处理

**Skill 解析 + Fallback 逻辑**：

```
slot.skill = "superpowers:brainstorming"
    ↓
检查 ~/.claude/skills/superpowers:brainstorming/ 是否存在
    ↓
存在 → 使用该 skill
不存在 → 检查 slot.fallback 字段
    ↓
fallback = "brainstorming"
    ↓
检查 ~/.claude/skills/brainstorming/ 是否存在（Superpowers 内置名）
    ↓
存在 → 使用 fallback
不存在 → 使用内置 fallback prompt（见下方 fallback prompt 表）
```

**Fallback prompt 表**（当 skill 和 fallback 都不可用时）：

| skill | fallback prompt |
|-------|----------------|
| brainstorming | 引导式提问 → 方案设计 → 保存到 `.harness/plans/` |
| subagent-driven-development | 按 plan 执行任务，遵守 TDD，self-verify 后交接 |
| finishing-a-development-branch | 验证测试 → 展示 merge/PR/keep/discard 选项 |

**派发 subagent**：通过 `Agent` 工具派发，带工具白名单、Turn 限制、MCP 配置（见上方 per-agent 配置）。

构造 subagent prompt（按上方上下文注入规则 + 工具白名单），通过 `Agent` 工具派发。

**per-agent 工具白名单约束**：

```
Planner（planner）：
  allowedTools: Read, Glob, Grep, WebSearch, Write
  disallowedTools: Edit, Bash, NotebookEdit
  maxTurns: 30
  goal: Deep investigation + full plan. No code implementation.

Builder（builder）：
  allowedTools: Read, Write, Edit, Glob, Grep, Bash
  disallowedTools: NotebookEdit, WebSearch
  maxTurns: 80
  permissionMode: acceptEdits
  goal: Strict TDD. Write test first, then minimum code to pass it.

Evaluator/Critic（critic）：
  allowedTools: Read, Write, Bash, WebSearch
  disallowedTools: Edit, Glob, Grep, NotebookEdit
  maxTurns: 40
  mcpServers: playwright  # if Playwright MCP is available
  goal: Black-box evaluation. Judge by running results only. Never read source code.

Finalizer（finalizer）：
  allowedTools: Read, Write, Bash
  disallowedTools: Edit, Glob, Grep, NotebookEdit, WebSearch
  maxTurns: 20
  goal: Clean finish. Create PR and docs. No major rewrites.
```

**⚠️ 预防性预算检查（在派发前执行）：**

基于 skill 类型和任务复杂度，估算本角色本次消耗量：

| skill 类型 | 典型输入 tokens | 典型输出 tokens | 估算单次消耗 |
|-----------|----------------|----------------|------------|
| brainstorming | ~3,000 | ~1,500 | $0.09 (sonnet) |
| subagent-driven-development | ~5,000 | ~3,000 | $0.15 (sonnet) |
| writing-plans | ~4,000 | ~2,000 | $0.12 (sonnet) |
| test-driven-development | ~4,000 | ~2,500 | $0.13 (sonnet) |
| harness-review | ~3,000 | ~1,000 | $0.08 (sonnet) |
| finishing-a-development-branch | ~2,000 | ~500 | $0.04 (sonnet) |
| 其他 / 未知类型 | ~3,000 | ~1,500 | $0.09 (sonnet) |

**检查逻辑：**
- 估算消耗 ≤ 剩余预算的 80%：直接派发
- 估算消耗在剩余预算 80%~100% 之间：派发前预警，告知用户"即将超支"
- 估算消耗 > 剩余预算：触发透支询问（见透支处理），**不先派发**

```
⚠️ {角色名} 预算即将耗尽
  剩余：${remaining}（估算）
  预计消耗：${estimated}（估算）
  预计超出：${overage}

  A. 继续执行（超支约 ${overage}）
  B. 停在这里
  C. 降级到更便宜的模型（省约 {pct}%）
```

### 4. 执行与后置预算检查

派发 subagent。subagent 完成后，计算本角色实际消耗的 token 数，换算估算费用（见费用估算）。

**后置检查（角色返回后）：**
- 剩余 > 20%：继续
- 剩余 ≤ 20%：触发透支询问（见透支处理）
- 已超出：按 overdraft 策略处理

### 5. 里程碑节点

若 `slot.milestone == true`，在角色完成后强制暂停：

```
🏁 里程碑：{slot.name} 完成

  {角色产出摘要（前300字）}

  确认继续进入下一步？(y / 有问题说一下)
```

等待用户确认后进入下一插槽。

---

## 费用估算

**价格表（用于 token → 美元换算）：**

| 模型 | 输入 $/M tokens | 输出 $/M tokens | 估算均价 $/M |
|-----|----------------|----------------|------------|
| claude-opus-4-6 | $15 | $75 | $30 |
| claude-sonnet-4-6 | $3 | $15 | $6 |
| claude-haiku-4-5 | $0.8 | $4 | $1.2 |

估算公式：`cost ≈ (input_tokens × input_price + output_tokens × output_price) / 1,000,000`

所有金额显示均附注"（估算）"，提示非精确计费。

---

## 透支处理

透支可能发生在两个阶段：**预防阶段**（派发前已预知会超支）和**反应阶段**（角色执行后才知道超支）。两种场景共用同一套策略。

**剩余 ≤ 20% 时（反应性预警）：**

```
⚠️ {角色名} 预算剩余约 ${remaining}（估算），预计还需约 ${needed}
继续透支？
  A. 透支继续（本次约 +${needed}）
  B. 停在这里，由我接手
  C. 降级到 {更便宜的模型} 完成剩余工作（省约 {pct}%）
```

**overdraft 策略处理：**

| 策略 | 预算耗尽时的行为 |
|------|---------------|
| `ask` | 展示上方透支询问，等待用户选择 |
| `allow` | 静默继续，完成后汇报实际超出金额 |
| `deny` | 立即终止角色，将已产出内容标记 `[TRUNCATED]` 传入下一插槽，输出：`⛔ {角色名} 预算耗尽（deny 策略），已截断并跳至下一步` |

---

## 完成汇总

所有插槽执行完毕后输出：

```
✅ 所有角色执行完毕

💰 本次开发估算费用：
  {角色名}: ${actual} / ${budget} 估算
  ...
  ─────────────────────
  合计：${total_actual} / ${total_budget} 估算

{如有超预算角色}
  ⚠️ {角色名} 超出预算 ${overage}（估算）
```

然后将控制权返回给 harness-dev，由 harness-dev 执行 Step 4（上下文沉淀）。
