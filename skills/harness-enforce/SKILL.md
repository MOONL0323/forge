---
name: harness-enforce
description: 机械执行层。将 constraints.md 中的规则翻译为可执行的 lint 规则、pre-commit hooks 和 CI 检查脚本。读取 constraints.md，解析 enforcement 块，生成对应脚本并注册到 .git/hooks/ 或 CI 配置。
---

# harness-enforce：机械执行层

> 这是 Forge 对 OpenAI Harness Engineering 核心理念的实现：
> "文档会腐烂，lint 规则不会。"

## 触发方式

- 用户执行 `/harness-enforce` 显式调用
- 在 `workflow/dev.md` 的 `enforcement` 块配置后，harness-onboard 自动调用（静默）
- 在 `harness-upgrade` 时自动调用（生成新的 enforcement 脚本）

## 核心原则

```
规则不被执行 = 规则不存在
```

如果一个约束没有被机械执行，它迟早会被违反。
harness-enforce 的目标：**将 constraints.md 中的每一条规则都变成代码。**

---

## Step 1：解析 enforcement 配置

读取 `.harness/workflow/dev.md` 中的 `enforcement:` YAML 块。

如果不存在，读取 `.harness/context/constraints.md`，从中提取可机器执行的规则。

**支持的 enforcement 类型：**

```yaml
enforcement:
  # 高频变更文件保护
  high-frequency-files:
    behavior: warn | block        # warn=警告+review，block=禁止合并
    threshold: 5                  # 30天内超过N次提交视为高频
    exclude: ["*_test.go", "*.json"]

  # pkg 接口变更通知
  pkg-interface-changes:
    behavior: notify | block
    notify-template: "@{owner} {pkg} 接口有变更"

  # 测试覆盖率要求
  test-requirement:
    behavior: block
    patterns: ["**/service/*.go", "**/handler/*.ts"]
    require-file-pattern: "*_test.*"

  # 文件大小限制
  file-size-limit:
    behavior: warn | block
    limit: 500                    # 行数限制
    exclude: ["*.pb.go", "**/generated/*"]

  # 禁止直接修改的文件
  protected-files:
    behavior: block
    patterns: [".env", "**/schema.sql", "**/config.prod.yaml"]

  # 日志规范
  logging-standard:
    behavior: warn | block
    forbid: ["console.log", "fmt.Print", "print("]
    require: ["logger.", "log.", "slog."]

  # 敏感信息检测
  secrets-detection:
    behavior: block
    patterns: ["password=", "api_key=", "secret=", "Token="]

  # 架构分层检查
  layer-violation:
    behavior: warn | block
    rules:
      - "ui 层禁止直接访问数据库"
      - "service 层禁止引用 ui 层"
      - "pkg 层禁止循环依赖"

  # TDD 强制规则
  # 要求实现代码必须先有对应测试，测试驱动开发
  tdd-enforcement:
    behavior: warn | block
    patterns: ["**/service/*.go", "**/handler/*.ts", "**/api/**/*.py"]
    test-pattern: "*_test.*"
    enforce_order: test-first   # test-first | implement-first | none
    # test-first = 任何实现变更前，对应测试必须已存在或同步变更
    # implement-first = 允许先写实现，但本次迭代结束前必须有测试
    # 深度检查：追踪 git diff 顺序，不只是文件存在性
    deep: true

  # Claude Code Hooks 自动生成
  # 根据 enforcement 配置自动生成 .claude/hooks/ 下的 hook 脚本
  auto-hooks:
    generate: true
    scope: project   # project = .claude/hooks/，global = ~/.claude/hooks/
    hooks:
      - type: PreToolUse      # 在 Write/Edit 前检查
        tools: ["Write", "Edit"]
        check: ["secrets", "file-size", "protected-files"]
      - type: PostToolUse     # 在工具执行后检查
        tools: ["Bash"]
        check: ["lint", "format"]
```

---

## Step 2：生成 enforcement 脚本

### A. pre-commit hook

生成 `.git/hooks/pre-commit` 脚本（或追加到已有的 hook）：

```bash
#!/bin/bash
# harness-enforce pre-commit hook
# 由 harness-enforce 自动生成，请勿手动修改

ENFORCE_FAILED=0

# 文件大小检查
for file in $(git diff --cached --name-only | grep -v -E '...'); do
  lines=$(wc -l < "$file")
  if [ "$lines" -gt 500 ]; then
    echo "⚠️  [enforce] 文件超过 500 行：$file ($lines 行)"
    echo "   Fix: 拆分为更小的模块，参考 docs/ARCHITECTURE.md#splitting-guide"
    if [ "$BEHAVIOR" = "block" ]; then
      ENFORCE_FAILED=1
    fi
  fi
done

# 敏感信息检测
for file in $(git diff --cached --name-only); do
  if git diff --cached "$file" | grep -iE 'password=|api_key=|secret=|Token=' > /dev/null; then
    echo "🚫 [enforce] 检测到疑似敏感信息：$file"
    echo "   Fix: 使用环境变量或 .env.example，不要提交真实凭据"
    ENFORCE_FAILED=1
  fi
done

# 日志规范检查
for file in $(git diff --cached --name-only | grep -E '\.(go|ts|js|py)$'); do
  if git diff --cached "$file" | grep -E 'console\.(log|debug|info)|fmt\.Print|print\(' > /dev/null; then
    echo "⚠️  [enforce] 发现禁止的日志调用：$file"
    echo "   Fix: 使用结构化日志（logger., log., slog.）"
    if [ "$BEHAVIOR" = "block" ]; then
      ENFORCE_FAILED=1
    fi
  fi
done

[ "$ENFORCE_FAILED" = "1" ] && exit 1
exit 0
```

### B. CI 检查脚本

生成 `.github/workflows/harness-enforce.yml`（GitHub Actions）：

```yaml
name: Harness Enforce

on:
  pull_request:
    paths-ignore:
      - '**.md'
      - '**.txt'
      - 'docs/**'

jobs:
  enforce:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 30  # 需要近30天历史用于高频文件检测

      - name: Run harness enforce checks
        run: |
          # 高频文件检查（30天内>5次提交）
          HIGH_FREQ=$(git log --oneline --since="30 days ago" --name-only | \
            grep -v '^$' | sort | uniq -c | sort -rn | \
            awk '$1 > 5 {print $2}' | grep -v -E '...')

          if [ -n "$HIGH_FREQ" ]; then
            echo "⚠️  高频变更文件（需额外 review）："
            echo "$HIGH_FREQ"
            echo "这些文件近期修改频繁，直接修改风险较高。"
            echo "建议通过 PR 或 pair programming 方式修改。"
          fi

      - name: Check test coverage
        run: |
          # 检查新增代码是否有对应测试
          echo "运行测试覆盖率检查..."
          # 具体实现根据项目测试框架调整

      - name: Secrets scan
        run: |
          # 使用 git-secrets 或 detect-secrets
          echo "扫描敏感信息..."
```

### C. Claude Code Hooks 脚本（.claude/hooks/）

根据 `auto-hooks:` 配置，生成 `.claude/hooks/` 下的 hook 脚本。

**生成目录**：
- `scope: project` → `.claude/hooks/`
- `scope: global` → `~/.claude/hooks/`

**Hook 类型与实现**：

```bash
#!/usr/bin/env bash
# .claude/hooks/pre-tool-use-secrets
# 由 harness-enforce 自动生成，禁止手动修改
# 检查 Write/Edit 操作是否包含敏感信息

read -r EVENT_DATA
FILE=$(echo "$EVENT_DATA" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)
CONTENT=$(echo "$EVENT_DATA" | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | cut -c1-500)

if echo "$CONTENT" | grep -iE 'password\s*=|api_key\s*=|secret\s*=|token\s*=' > /dev/null 2>&1; then
  echo "🚫 [enforce] 检测到疑似敏感信息：$FILE"
  echo 'Fix: 使用环境变量或 .env.example，不要在代码中硬编码凭据'
  echo '{"continue": false, "additionalContext": "检测到敏感信息硬编码，使用环境变量替代"}'
  exit 2  # exit 2 = block in PreToolUse
fi

echo '{"continue": true, "suppressOutput": true}'
exit 0
```

```bash
#!/usr/bin/env bash
# .claude/hooks/post-tool-use-lint
# 由 harness-enforce 自动生成，禁止手动修改
# 在 Bash 工具执行后自动运行 lint

read -r EVENT_DATA
COMMAND=$(echo "$EVENT_DATA" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)

# 如果是测试命令，执行后检查覆盖率
if echo "$COMMAND" | grep -q "pytest\|go test\|jest\|npm test"; then
  RESULT=$(echo "$EVENT_DATA" | grep -o '"output":"[^"]*"' | tail -1 | cut -d'"' -f4 | cut -c1-1000)
  if echo "$RESULT" | grep -q "FAIL\|ERROR\|failed"; then
    echo "⚠️  [enforce] 测试失败"
    echo '{"continue": true, "additionalContext": "测试失败，请修复后再继续。Fix: 运行测试命令查看详细错误"}'
  fi
fi

echo '{"continue": true, "suppressOutput": true}'
exit 0
```

**settings.json 注册**：
```json
{
  "hooks": [
    {
      "name": "pre-tool-use-secrets",
      "hooks": [{
        "type": "PreToolUse",
        "env": {
          "PATH": "/usr/local/bin:/usr/bin:/bin"
        }
      }]
    },
    {
      "name": "post-tool-use-lint",
      "hooks": [{
        "type": "PostToolUse",
        "env": {
          "PATH": "/usr/local/bin:/usr/bin:/bin"
        }
      }]
    }
  ]
}
```

### D. TDD 强制 hook（深度版）

```bash
#!/usr/bin/env bash
# .claude/hooks/pre-tool-use-implement
# 由 harness-enforce 自动生成，强制 TDD 顺序
# 深度追踪：检查 git diff 顺序，确保测试文件变更先于实现文件

read -r EVENT_DATA
TOOL=$(echo "$EVENT_DATA" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)

# 只检查 Write/Edit 操作
if [ "$TOOL" != "Write" ] && [ "$TOOL" != "Edit" ]; then
  echo '{"continue": true, "suppressOutput": true}'
  exit 0
fi

# 获取本次会话的已修改文件列表（来自 git）
CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null)
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)
ALL_CHANGED="$STAGED_FILES"$'\n'"$CHANGED_FILES"

# 分离测试文件和实现文件
TEST_PATTERNS="(_test\.|_spec\.|\.test\.|\.spec\.)"
declare -a TEST_FILES IMPLEMENT_FILES

for FILE in $ALL_CHANGED; do
  [ -z "$FILE" ] && continue
  if echo "$FILE" | grep -qE "$TEST_PATTERNS"; then
    TEST_FILES+=("$FILE")
  else
    IMPLEMENT_FILES+=("$FILE")
  fi
done

# 获取 git diff 顺序（文件在 diff 中出现的顺序）
# 最近修改的文件排在最前面
RECENT_FIRST=$(git diff --name-only HEAD 2>/dev/null | head -20)

# 检查：最近的修改中，测试文件是否出现在实现文件之前
LAST_TEST_LINE=0
LAST_IMPL_LINE=0
LINE_NUM=0
for F in $RECENT_FIRST; do
  LINE_NUM=$((LINE_NUM + 1))
  if echo "$F" | grep -qE "$TEST_PATTERNS"; then
    LAST_TEST_LINE=$LINE_NUM
  else
    LAST_IMPL_LINE=$LINE_NUM
  fi
done

# TDD 顺序判定
if [ ${#IMPLEMENT_FILES[@]} -gt 0 ] && [ ${#TEST_FILES[@]} -eq 0 ]; then
  echo "🚫 [enforce] TDD 违规：存在实现变更但无对应测试"
  echo "Fix: 先写测试，或使用 /tdd 辅助工作流"
  echo '{"continue": true, "additionalContext": "TDD 强制：实现变更前必须有对应测试文件存在或同步变更。TDD workflow: /tdd"}'
  exit 0  # warn only，不阻塞
fi

if [ $LAST_IMPL_LINE -gt 0 ] && [ $LAST_TEST_LINE -eq 0 ]; then
  echo "🚫 [enforce] TDD 顺序违规：先改了实现，再改测试（违反 test-first）"
  echo "实现文件：${IMPLEMENT_FILES[*]}"
  echo "Fix: 先撤销实现变更，先改测试。或者使用 /tdd 走完整 TDD 流程"
  echo '{"continue": true, "additionalContext": "TDD test-first 违规：检测到实现文件变更但测试文件未被修改。请先改测试（RED），再改实现（GREEN）。"}'
  exit 0  # warn only，不阻塞
fi

if [ $LAST_IMPL_LINE -gt 0 ] && [ $LAST_TEST_LINE -gt 0 ] && [ $LAST_TEST_LINE -lt $LAST_IMPL_LINE ]; then
  echo "✅ [enforce] TDD 顺序正确：测试先于实现"
fi

echo '{"continue": true, "suppressOutput": true}'
exit 0
```

**为什么用 exit 0（warn）而不是 exit 2（block）？**
TDD 顺序的强制需要完整的 git diff 上下文。hook 只能看到部分变更。
建议通过 CI 的完整 diff 检查来 block，或者在 `/harness-dev` 的 builder 步骤强制执行。



每个 enforcement 规则的错误信息必须包含修复指令（参考 OpenAI 原文）：

```
❌ 错误示例：
Error: File exceeds 500 lines.

✅ 正确示例（harness-enforce 标准）：
Error: File exceeds 500 lines.
Fix: 将文件拆分为领域特定模块。
     参考：context/arch.md#splitting-guide
     建议：提取类型到 <domain>/types/，
           提取服务逻辑到 <domain>/service/，
           提取入口到 <domain>/cmd/。
     如需帮助，运行 /harness-init 并更新 arch.md。
```

---

## Step 4：注册 enforcement 脚本

1. **pre-commit hook**：
   - 如果 `.git/hooks/pre-commit` 不存在：直接写入
   - 如果已存在：追加 harness-enforce 代码段（用 `# === HARNESS-ENFORCE START ===` 标记）
   - 执行 `git config core.hooksPath .git/hooks` 确保 hook 生效

2. **CI 脚本**：
   - 生成 `.github/workflows/harness-enforce.yml`
   - 如果 `.github/workflows/` 不存在，先创建
   - 如果已存在同名 workflow，追加 jobs 而非覆盖

3. **Claude Code Hooks（.claude/hooks/）**：
   - 如果 `.claude/hooks/` 不存在：创建目录
   - 生成对应 hook 脚本（pre-tool-use-secrets, post-tool-use-lint, pre-tool-use-implement 等）
   - 追加/更新 `settings.json` 中的 hook 注册配置
   - 设置为可执行（`chmod +x`）

4. **显示配置摘要**：

```
✅ harness-enforce 安装完成

已注册检查：
  ✅ 文件大小限制（>500 行 → warn/block）
  ✅ 敏感信息检测（password/api_key/secret → block）
  ✅ 日志规范（console.log/fmt.Print → warn）
  ✅ 高频文件检测（30天内>5次提交 → warn）
  ✅ Claude Code Hooks（.claude/hooks/ 下的 PreToolUse/PostToolUse 脚本）
  ✅ TDD 强制 hook（implement 变更前检查对应测试）

待配置（可在 dev.md 中启用）：
  ⏳ pkg 接口变更通知
  ⏳ 测试覆盖率要求
  ⏳ 架构分层检查
  ⏳ TDD enforce_order: test-first（严格模式）

如需更新规则，执行 /harness-enforce 重新生成。
```

---

## Step 5：验证 enforcement

运行 `/harness-enforce` 后，执行验证：

```bash
# 测试 pre-commit hook
git add test_file.go
git commit -m "test" || echo "Hook 拦截成功"
```

---

## 与 constraints.md 的关系

```
constraints.md          →  自然语言规则（人读）
dev.md enforcement:     →  机器可执行规则（机器读）
harness-enforce         →  将后者翻译为实际脚本
```

**最佳实践**：
1. 在 `constraints.md` 中用自然语言记录规则意图
2. 在 `dev.md` 的 `enforcement:` 块中用 YAML 描述可执行版本
3. 运行 `/harness-enforce` 生成实际脚本
4. enforcement 失败时，错误信息指引回 `constraints.md` 对应章节

---

## 更新 enforcement

当 `dev.md` 的 `enforcement:` 块变更时：

```bash
/harness-enforce
```

harness-enforce 会：
1. 重新解析 `enforcement:` 配置
2. 更新 `pre-commit` hook（保留非 harness-enforce 的其他 hook 代码）
3. 更新 CI workflow
4. 更新 `.claude/hooks/` 下的 hook 脚本
5. 展示变更摘要

---

## 回滚 enforcement

如需禁用所有 enforcement：

```bash
# 删除 pre-commit hook 中的 harness-enforce 段
/harness-enforce --disable

# 删除 CI workflow
rm .github/workflows/harness-enforce.yml

# 删除 Claude Code hooks（保留其他非 harness-enforce 的 hooks）
rm .claude/hooks/pre-tool-use-secrets
rm .claude/hooks/post-tool-use-lint
rm .claude/hooks/pre-tool-use-implement
```

注意：回滚 enforcement 不影响 `constraints.md` 中的规则——只是停止机器执行，规则仍然存在。
