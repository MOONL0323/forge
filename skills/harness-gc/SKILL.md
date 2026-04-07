---
name: harness-gc
description: 熵管理/垃圾回收。定期扫描仓库中的代码漂移、文档腐烂、架构违规，生成修复 PR。防止智能体复现坏模式，保持 harness 上下文与实际代码同步。技术债 = 高息贷款，harness-gc = 持续小额定投。
---

# harness-gc：熵管理与垃圾回收

> 参考：OpenAI Harness Engineering — "智能体会复现仓库中已有的模式，包括坏模式"
> 类比：技术债 = 高息贷款；定期回收 = 持续小额定投

## 触发方式

- 用户执行 `/harness-gc` 手动触发
- 定时触发：配置在 `.harness/workflow/dev.md` 中（见 Step 4）
- 在 `harness-upgrade` 后自动触发（扫描旧架构规则是否还适用）

---

## 熵的类型与检测

### 1. 文档腐烂（Documentation Rot）

**检测：** arch.md / constraints.md 中的描述与实际代码不符

```bash
# 检查文档中提到的文件/函数是否还存在
# 检查文档提到的架构模式是否被遵守
```

**示例：**
```
⚠️ 文档腐烂

  arch.md 说："所有数据库访问通过 db/ 层的 Repo 接口"
  实际：发现 {N} 处直接调用 sql.DB

  arch.md 说："使用 config.yaml 配置"
  实际：发现硬编码配置值

  ⚠️ 建议：在 arch.md 中修正，或通过 harness-enforce 强制执行架构规则
```

### 2. 模式漂移（Pattern Drift）

**检测：** 代码中出现了与项目规范不一致的模式

```bash
# 高频变更文件中的新模式
# 重复的辅助函数（DRY 违规）
# 不一致的错误处理风格
# YOLO 式数据访问（无类型验证）
```

**检测规则：**
```yaml
drift-checks:
  duplicate-helpers:
    enabled: true
    threshold: 3   # 出现3次以上相似的 helper → 建议提取

  error-handling:
    enabled: true
    forbid: ["panic(", "os.Exit("]
    patterns:
      - "直接 return err without wrapping"
      - "忽略 _ = function()"

  yolo-patterns:
    enabled: true
    forbid:
      - 'fmt.Sprintf("%s", '
      - 'json.Unmarshal(jsonObj, '
      - 'interface{}(nil)'
```

### 3. 架构违规（Architectural Violations）

**检测：** 违反 arch.md 中定义的层次结构

```bash
# ui 层是否直接访问了数据库？
# service 层是否引用了 ui 层？
# 是否存在循环依赖？
```

### 4. 上下文陈旧（Context Staleness）

**检测：** context 文件是否已过时

```yaml
staleness-checks:
  module-md-updated:
    max-age: 90d   # 超过90天未更新 → 提示审核

  arch-md-violations:
    enabled: true  # 检测 arch.md 描述与实际的偏差

  constraints-md-coverage:
    enabled: true   # constraints.md 是否覆盖了所有已知风险
```

---

## Step 1：执行扫描

### 扫描命令

```bash
# 1. 文档一致性检查
echo "=== 文档一致性检查 ==="
# 提取 arch.md 中提到的所有文件路径，检查是否还存在

# 2. 高频变更文件扫描
echo "=== 高频变更文件（30天）==="
git log --oneline --since="30 days ago" --name-only | \
  grep -v '^$' | sort | uniq -c | sort -rn | head -10

# 3. 重复代码检测
echo "=== 重复模式检测 ==="
# 使用 cpd 或 custom script 检测重复

# 4. 架构层违规检测
echo "=== 架构层检查 ==="
# 检查跨层依赖

# 5. 测试覆盖率趋势
echo "=== 测试覆盖率 ==="
# 与上次 gc 的覆盖率对比
```

---

## Step 2：生成熵报告

```
📊 harness-gc 熵报告 — {date}

## 🔴 高优先级（建议本周处理）

  1. [架构违规] ui 层直接访问数据库 ×3
     文件：ui/dashboard.go, ui/reports.go
     建议：提取到 db/ 层，通过接口调用

  2. [敏感信息] 2 个文件中存在疑似硬编码凭据
     文件：config/local.yaml, scripts/deploy.sh
     建议：移到环境变量，运行 /harness-enforce 检查

## 🟡 中优先级（建议本月处理）

  3. [模式漂移] 重复的 input validation helper ×5 处
     建议：提取到 pkg/validators/

  4. [文档腐烂] arch.md 提到已删除的 auth/ 模块
     建议：更新 arch.md 或确认模块确实被移除

  5. [上下文陈旧] module.md 超过 90 天未更新
     建议：审核 module.md 是否反映当前状态

## 🟢 低优先级（建议本季度处理）

  6. [代码异味] 2 个文件超过 600 行
  7. [错误处理] 3 处裸 return err
  8. [测试覆盖] service 层测试覆盖率低于 60%

## 📈 趋势

  上次 GC（{date}）发现 {N} 个问题，已修复 {M} 个
  问题存量：{prev} → {current}（{delta}）

  建议：{趋势分析}

## 🔄 Golden Rules 提案

  GC 检测到 {K} 个可编码为规则的问题：

  ① [drift-{N}] {规则描述}
     → 来源：{检测到 N 次重复}
     → 提案：写入 golden-rules.md + enforce
     → A. 确认编码  B. 忽略  C. 手动修复

  （选择 A 后，GC 自动写入约束并调用 harness-enforce --update）
```

---

## Step 3：生成修复 PR + Golden Rules 确认

### A. 修复 PR 生成

```
⚠️ 发现 {N} 个高优先级熵问题

自动生成修复 PR？

  A. 生成 PR（包含所有高优先级问题修复）
  B. 只生成 PR（包含已确认安全的修复，跳过需审核的）
  C. 不生成，只生成报告

  选择：
```

### C. CI Failure Auto-Fix Workflow

> 官方 GitHub Actions 模式：CI 失败后自动触发 Claude Code 修复。
> 触发条件：GitHub Actions workflow_run 事件（CI 失败时）

**生成的 workflow 文件**（`.github/workflows/harness-ci-auto-fix.yml`）：

```yaml
name: Harness CI Auto-Fix

on:
  workflow_run:
    workflows: ["CI", "Test", "Build"]
    types: [completed]
    branches: [main, develop]

permissions:
  contents: write
  id-token: write   # Required for OIDC token auth

jobs:
  ci-failure-auto-fix:
    if: github.event.workflow_run.conclusion == 'failure'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.workflow_run.head_branch }}

      - name: Configure git
        run: |
          git config user.name "Claude Code"
          git config user.email "claude+ci@auto-fix"

      - name: Get failed job info
        id: job-info
        run: |
          # 通过 GitHub API 获取失败的 job 详情
          JOBS_JSON=$(curl -s -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
            "${{ github.api_url }}/repos/${{ github.repository }}/actions/runs/${{ github.event.workflow_run.id }}/jobs")

          FAILED_JOB=$(echo "$JOBS_JSON" | jq -r '.jobs[] | select(.conclusion == "failure") | .name' | head -1)
          FAILED_JOB_URL=$(echo "$JOBS_JSON" | jq -r '.jobs[] | select(.conclusion == "failure") | .html_url' | head -1)
          RUN_ID=${{ github.event.workflow_run.id }}

          echo "FAILED_JOB=$FAILED_JOB" >> $GITHUB_OUTPUT
          echo "FAILED_JOB_URL=$FAILED_JOB_URL" >> $GITHUB_OUTPUT
          echo "RUN_ID=$RUN_ID" >> $GITHUB_OUTPUT

          # 下载失败日志（保留完整上下文）
          LOGS_URL=$(echo "$JOBS_JSON" | jq -r '.jobs[] | select(.conclusion == "failure") | .logs_url' | head -1)
          curl -s -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
            "$LOGS_URL" | gzip -d > /tmp/failed_logs.txt 2>/dev/null || echo "LOG_FETCH_FAILED" > /tmp/failed_logs.txt

          echo "JOB_NAME=$FAILED_JOB" >> $GITHUB_ENV
          echo "logs saved to /tmp/failed_logs.txt"

      - name: Create fix branch
        run: |
          # 官方命名格式：claude-auto-fix-ci-{branch}-{run_id}
          BRANCH_NAME="claude-auto-fix-ci-${{ github.event.workflow_run.head_branch }}-${{ github.event.workflow_run.id }}"
          git checkout -b "$BRANCH_NAME"
          echo "BRANCH_NAME=$BRANCH_NAME" >> $GITHUB_OUTPUT

      - name: Run Claude Code to fix CI failure
        uses: anthropics/claude-code-action@v1
        env:
          CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
        with:
          # 使用 /fix-ci 命令触发修复
          prompt: |
            /fix-ci

            失败信息：
            - Job: ${{ steps.job-info.outputs.FAILED_JOB }}
            - Job URL: ${{ steps.job-info.outputs.FAILED_JOB_URL }}
            - Run ID: ${{ steps.job-info.outputs.RUN_ID }}

            失败日志位于 /tmp/failed_logs.txt，请读取后进行修复。
        # 限制可用工具，确保安全操作
        allowedTools: |
          Read
          Write
          Edit
          Bash
          Glob
          Grep

      - name: Create auto-fix PR
        if: success()
        run: |
          # 检查是否有 commit 需要 push
          if git log origin/${{ github.event.workflow_run.head_branch }}..HEAD --oneline | head -1 > /dev/null 2>&1; then
            git push -u origin ${{ env.BRANCH_NAME }} 2>/dev/null && \
            gh pr create \
              --base ${{ github.event.workflow_run.head_branch }} \
              --head ${{ env.BRANCH_NAME }} \
              --title "🤖 CI Auto-Fix: ${{ env.JOB_NAME }}" \
              --body "由 harness-ci-auto-fix 自动生成。

修复了 CI 失败问题（Job: ${{ env.JOB_NAME }}）。

失败日志：${{ steps.job-info.outputs.FAILED_JOB_URL }}

⚠️ 如果此修复无效，请在 3 次尝试后停止 auto-fix 并人工介入。"
            || echo "PR creation failed, branch still pushed for manual review"
          else
            echo "No commits to push - CI issue may be environment-related"
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Report failure
        if: failure()
        run: |
          echo "⚠️  Claude Code 无法自动修复 CI 失败"
          echo "请人工介入检查：${{ steps.job-info.outputs.FAILED_JOB_URL }}"
```

**同时创建 `/fix-ci` 命令**（`.claude/commands/fix-ci.md`）：

```markdown
# Fix CI Failure

分析 CI 失败日志，修复问题，提交并 push。

## 输入
- /fix-ci [job_name]

## 你的任务

1. 读取 /tmp/failed_logs.txt（CI 失败日志）
2. 分析失败原因（编译错误 / 测试失败 / lint 失败 / 环境问题）
3. 修复具体问题
4. 运行 `git diff` 确认修改
5. commit：`fix: CI failure in {job_name}（自动修复）`
6. push 到当前 branch

## 约束
- 只修复导致 CI 失败的具体问题，不要做大范围重构
- 如果是环境问题（时区、网络、超时），在 PR body 中说明
- 如果修复后 CI 仍失败，记录原因并停止
```

**自动触发条件**：
- CI / Test / Build workflow 失败
- 分支：main 或 develop
- 创建 `claude-auto-fix-ci-{branch}-{run_id}` branch（官方命名格式）
- 自动运行 `/fix-ci` 命令
- 创建 PR 到失败分支

**防循环触发**：
- 只监听 `workflow_run` 事件，不监听 PR/push
- `id-token: write` 用于 OIDC 安全认证
- `allowedTools` 限制工具为 Read/Write/Edit/Bash/Glob/Grep（无 rm/dangerous）

**最多 3 次尝试**，仍失败则停止并通知人工介入。

### B. Golden Rules 闭环确认

```
🔄 检测到 {K} 个可编码为规则的问题：

  ① [模式重复] 3 个文件都有相同的 validation 逻辑
     → 建议：提取到 pkg/validators/，添加到 golden-rules.md

  ② [错误处理] 5 处裸 return err
     → 建议：添加到 golden-rules.md + enforce

对每个提案选择：
  A. 确认编码（写入 golden-rules.md + harness-enforce --update）
  B. 忽略（不做规则，只报告）
  C. 手动修复（不在此 PR 中处理）
```

**当用户选择 A（确认编码）时：**
```bash
# 1. GC 自动将规则写入 .harness/golden-rules.md
# 2. 调用 harness-enforce --update 生成对应 hook
# 3. 验证 hook 已注册
echo "✅ Golden Rule 已编码，下次 GC 将检查执行情况"
```

---

## Step 4：配置定时扫描

在 `.harness/workflow/dev.md` 中配置：

```yaml
gc:
  # 自动触发间隔：weekly | biweekly | monthly | manual
  schedule: weekly

  # 扫描范围
  scope:
    - drift-checks       # 模式漂移
    - arch-violations    # 架构违规
    - doc-staleness      # 文档陈旧
    - test-coverage      # 测试覆盖率

  # 自动生成 PR
  auto-pr: false         # true = 高优先级问题自动生成 PR
  auto-pr-min-priority: high  # high | medium

  # 通知方式
  notify:
    - type: pr           # 生成 PR 作为通知
    # - type: slack      # Slack 通知（如配置了 webhook）
    # - type: comment    # 在现有 PR 中评论
```

**GitHub Actions 配置（定时触发）：**

```yaml
# .github/workflows/harness-gc.yml
name: Harness GC

on:
  schedule:
    - cron: '0 9 * * MON'  # 每周一早上 9 点

jobs:
  gc:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run harness-gc
        run: |
          # 在 Claude Code 会话中执行 /harness-gc --report
          # 或使用 CLI 工具
```

---

## Step 5：持续改进

### 技术债定投策略

| 还债方式 | 适用场景 |
|---------|---------|
| 每次 PR 附带修复 | 改动相关的小问题 |
| harness-gc PR | 独立的熵清理 |
| 大块重构 | 无法渐进修复的结构性问题 |

### Golden Rules（自动化闭环）

> **核心理念：检测 → 编码 → 强制执行 → 验证，形成持续反馈闭环。**
> 检测到的问题不应该只停留在报告里，而应该变成可执行的规则。

#### 闭环流程

```
GC 检测到重复问题（N 次）
    ↓
自动分析问题模式
    ↓
生成 Golden Rule 提案（human-in-the-loop）
    ↓
用户确认后，写入 constraints.md enforcement 块
    ↓
harness-enforce 生成对应 lint/hook 脚本
    ↓
从此这个问题被机器自动阻止
```

#### 自动规则生成示例

当 GC 发现"3 个不同文件都有相同的 input validation 逻辑"时：

```
🔄 自动检测到重复模式

  问题：3 个文件存在相同的 input validation 逻辑
  文件：src/api/user.go, src/api/order.go, src/api/product.go
  代码片段：
    if req.UserID == "" {
      return errors.New("user_id is required")
    }
    if req.UserID != "" && len(req.UserID) < 8 {
      return errors.New("user_id too short")
    }

📝 GC 自动生成 Golden Rule 提案：

  规则名称：validate-required-string
  规则描述：所有 API handler 的必填字符串参数使用共享验证器
  建议：
    1. 提取到 pkg/validators/required.go
    2. 在 constraints.md 中添加：
       enforcement:
         golden-rules:
           - "API 必填参数使用 pkg/validators/ 而非内联验证"
  执行方式：建议修复（warn），或强制执行（block）

✅ 接受后 GC 自动：
  1. 将规则写入 .harness/golden-rules.md
  2. 调用 harness-enforce 生成对应 hook
  3. 后续 GC 检查时验证规则是否被执行
```

#### .harness/golden-rules.md 格式

```yaml
# 由 GC 自动生成 + 人工确认
golden-rules:
  - id: gr-001
    name: "validate-required-string"
    content: "所有 API handler 的必填字符串参数使用 pkg/validators/"
    source: "gc@2026-04-07（检测到 3 处重复）"
    enforcement: warn    # warn | block
    status: active       # active | archived
    auto_generated: true
    confirmed_at: "2026-04-07T14:00:00Z"

  - id: gr-002
    name: "no-direct-sql"
    content: "禁止直接访问 sql.DB，必须通过 Repo 接口"
    source: "arch.md@2026-04-01"
    enforcement: block
    status: active
    auto_generated: false
```

#### GC 自动检测 + 编码触发条件

```
GC 自动生成 Golden Rule 的条件：
  1. 同一模式在 ≥ 3 个文件中出现
  2. 同一类错误（裸 return err、无验证等）在 30 天内出现 ≥ 5 次
  3. 架构违规在 ≥ 2 个模块中重复出现

触发流程：
  GC 报告 → 用户说"把这条加到规则" → GC 自动写入 golden-rules.md
  → 调用 harness-enforce --update
```

---

## 与其他 harness skills 的关系

```
harness-gc         →  定期发现熵 + 生成 Golden Rule 提案
harness-enforce    →  将 Golden Rules 翻译为可执行脚本
harness-init       →  初始化时建立规则
harness-upgrade    →  升级时检查规则是否过时

完整闭环：
  GC 发现重复模式
    ↓
  生成 Golden Rule 提案
    ↓
  人工确认（选 A/B/C）
    ↓
  写入 golden-rules.md + enforce 生成 hook
    ↓
  后续自动阻止同类问题
    ↓
  GC 验证规则执行情况
```

---

## 回滚

如需禁用 harness-gc：
1. 删除 `.github/workflows/harness-gc.yml`
2. 在 `dev.md` 中设置 `gc.schedule: manual`
