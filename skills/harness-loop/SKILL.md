---
name: harness-loop
description: Ralph Wiggum 自主循环引擎。将任务拆解为小颗粒 story，按序执行直到全部完成或达到迭代上限。每次迭代使用新鲜 subagent 上下文，通过任务状态文件实现会话间的持久化。适配 harness-harness（驭缰工程）框架。
---

# harness-loop：Ralph Wiggum 自主循环

> 参考：OpenAI Harness Engineering + Ralph Wiggum Pattern
> 核心信条：Fresh Context Is Reliability / The Plan Is Disposable / Disk Is State, Git Is Memory

## Ralph Wiggum Core Principles

| Principle | Implementation |
|-----------|---------------|
| Fresh Context Is Reliability | Each iteration = fresh subagent, no inherited history |
| The Plan Is Disposable | Plan can be discarded at any time. Regeneration cost = 1 loop |
| Disk Is State, Git Is Memory | Task state on disk, git commits = handoff mechanism |
| Steer With Signals | Control via checkpoints and gates, not scripts |

## 触发方式

- 用户执行 `/harness-loop` 启动
- 用户说"让 agent 自主运行"、"跑 ralph"、"循环执行"
- 后台模式：`/harness-loop --background --max-iterations 20`

---

## Step 1：任务准备

### 检查或创建任务文件

检查 `.harness/loop/` 目录：

```
.harness/loop/
├── tasks.json        # 任务列表（与 prd.json 格式兼容）
├── state.json        # 当前状态（当前任务、迭代计数）
├── progress.md       # 增量学习日志（append-only）
└── archive/          # 历史运行存档
    └── YYYY-MM-DD-feature-name/
```

**如果用户提供了任务列表**：生成 `tasks.json`
**如果 `.harness/loop/tasks.json` 已存在**：继续上次运行
**如果既无任务也无 tasks.json**：引导用户生成任务

### Task Format (tasks.json)

```json
{
  "project": "{module name}",
  "branchName": "ralph/{feature-name}",
  "description": "{task description}",
  "maxIterations": 20,
  "stories": [
    {
      "id": "ST-001",
      "title": "{story title}",
      "description": "{concrete description}",
      "acceptanceCriteria": [
        "Verifiable criterion 1",
        "Verifiable criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Story Granularity Rule

> **Most important rule: Each story must be completable in one iteration (one context window).**

| Size | Rule | Example |
|------|------|---------|
| ✅ Right | Describable in 2-3 sentences | "Add status column to tasks table" |
| ❌ Too big | Requires "first...then..." | "Implement complete user auth system" |
| ❌ Too small | Done in 5 minutes | "Fix a typo" |

**Task splitting example:**
```
❌ "Build entire dashboard"
✅ ST-001: Add notifications table to DB
✅ ST-002: Create notification service
✅ ST-003: Add notification icon to header
✅ ST-004: Create notification dropdown panel
✅ ST-005: Add read/unread marking
```

---

## Step 2：环境准备

### 创建或使用 worktree

```bash
# 检查是否已有对应 worktree
git worktree list | grep "ralph/{feature-name}"

# 如果没有，创建新的
git worktree checkout -b "ralph/{feature-name}"
# 或
git fetch && git worktree add "../worktrees/ralph-{feature-name}" "origin/main"
```

### 初始化进展日志

```bash
echo "# Ralph Progress Log — {feature-name}" >> .harness/loop/progress.md
echo "Started: $(date)" >> .harness/loop/progress.md
echo "---" >> .harness/loop/progress.md
```

### 环境验证

在开始前验证基本质量门：
- `go build ./...` 或 `npm build` 或 `cargo build`
- 测试可运行：`go test ./...` / `npm test` / `cargo test`
- 如果 build 或基本测试失败，提示用户修复后再启动 loop

---

## Step 3：主循环

```
WHILE 当前 story 未全部完成 AND 迭代次数 < maxIterations:
    1. 选择最高优先级且 passes=false 的 story
    2. 派发 fresh subagent 执行该 story
    3. subagent 返回后：
       a. 检查 acceptance criteria
       b. 如果全部通过 → marks passes=true，commit
       c. 如果未通过 → 记录 notes，追加到 progress.md
    4. 询问用户 checkpoint（每 3 个 story 执行一次）
    5. 迭代次数 +1
END
```

### 循环启动提示

```
🔄 Ralph Loop 启动

  项目：{project}
  分支：{branchName}
  任务数：{total} 个（{completed} 个已完成）
  最大迭代：{maxIterations} 次

  📋 当前任务：ST-001 — {title}

  Agent 将以新鲜上下文执行此任务，完成后自动进入下一个。
  Ctrl+C 可随时中断，已完成工作已提交到分支。

  开始？
```

### Fresh Subagent 上下文构造

每次迭代的 subagent prompt 必须只包含**它需要知道的信息**：

```
你是 Ralph Builder，正在执行任务 ST-001。

## 任务
{story.title}
{story.description}

## Acceptance Criteria（必须全部验证）
- {criterion 1}
- {criterion 2}
- Typecheck passes

## 当前仓库状态
最近一次 commit: {last_commit_hash} — {last_commit_message}
当前分支: {branchName}

## 约束
- 只修改完成这个 story 必需的文件
- 每次修改后立即运行对应测试
- 完成后 commit，格式: "ST-001: {title}"

## 执行
开始执行。如果 acceptance criteria 全部满足，说 "DONE"。
如果遇到无法解决的问题，说 "BLOCKED: {原因}" 并停止。
```

### Checkpoint 机制

每执行完 3 个 story（或手动触发）：

```
⏸ Checkpoint — 已完成 {N} 个任务

  ✅ ST-001: {title}
  ✅ ST-002: {title}
  ✅ ST-003: {title}

  接下来：ST-004 — {title}

  请确认继续，或：
  - 说「检查 ST-002」查看详情
  - 说「修改 plan」调整计划
  - 说「暂停」保存状态，稍后继续
```

### 循环完成

```
✅ Ralph Loop 完成

  总迭代：{N} 次
  完成任务：{completed}/{total}
  跳过任务：{skipped} 个
  分支：{branchName}

  产出摘要：
  {git log --oneline -N}

  建议下一步：
    - 查看 git diff 确认变更
    - 运行完整测试套件
    - 创建 PR 或合并
```

---

## Step 4：状态持久化

### 任务状态文件（tasks.json）

每次 story 完成或更新后，立即写入 `.harness/loop/tasks.json`：

```bash
# 更新 tasks.json
jq '.stories[0].passes = true | .stories[0].notes = "..."' \
  .harness/loop/tasks.json > .harness/loop/tasks.json.tmp
mv .harness/loop/tasks.json.tmp .harness/loop/tasks.json
git add .harness/loop/tasks.json
git commit -m "Ralph: update tasks.json"
```

### 进展日志（progress.md）

Append-only，不修改历史：

```bash
echo "" >> .harness/loop/progress.md
echo "[$(date '+%Y-%m-%d %H:%M')] ST-001 完成" >> .harness/loop/progress.md
echo "  学到：{新发现的模式或坑}" >> .harness/loop/progress.md
echo "  git: {commit-hash}" >> .harness/loop/progress.md
```

### 存档机制

如果分支名变更（例如切换到另一个 feature）：

```bash
# 存档之前的运行
ARCHIVE_DIR=".harness/loop/archive/$(date '+%Y-%m-%d')-{feature-name}"
mkdir -p "$ARCHIVE_DIR"
cp .harness/loop/tasks.json "$ARCHIVE_DIR/"
cp .harness/loop/progress.md "$ARCHIVE_DIR/"
```

---

## Step 5：质量门（Backpressure）

在每个 story 完成时强制检查：

| 检查 | 失败行为 |
|------|---------|
| Typecheck / Lint | block，不允许继续 |
| 相关测试 | block，不允许继续 |
| 业务逻辑验证 | warn，告知用户 |

```
🔍 质量门检查

  Typecheck ... ✅
  测试 ... ✅
  Lint ... ✅

  全部通过。Story ST-001 标记为完成。
```

---

## 错误处理

| 错误类型 | 处理方式 |
|---------|---------|
| subagent BLOCKED | 记录 notes，询问用户干预 |
| 测试失败 | 阻止提交，汇报失败原因 |
| 达到 maxIterations | 展示已完成/未完成，询问继续或存档 |
| 环境错误（build fail）| 停止 loop，要求用户修复环境 |
| 用户 Ctrl+C | 立即 commit 当前状态，显示恢复指令 |

---

## 会话恢复

下次进入时，检测 `.harness/loop/tasks.json` 是否存在且有未完成任务：

```
🔄 检测到未完成的 Ralph Loop

  项目：{project}
  上次运行：{date}
  进度：{completed}/{total} 个完成

  继续上次的循环？或重新开始？
```

---

## 与 harness-dev 的关系

```
harness-dev     →  人类参与的工作流（单次会话）
harness-loop     →  自主循环工作流（无人值守）

harness-loop 是 harness-dev 的超集：
  在每个 story 执行时，内部调用 harness-dev 的角色编排逻辑
  添加了循环 + 持久化 + checkpoint 机制
```

---

## 启动参数

| 参数 | 说明 | 默认值 |
|------|------|-------|
| `--max-iterations N` | 最大迭代次数 | 20 |
| `--background` | 后台运行模式 | 前台 |
| `--story "title"` | 指定执行某个 story | 按优先级 |
| `--skip-test` | 跳过质量门测试 | false |
