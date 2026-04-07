---
name: harness-validate
description: Claude Code 文件全面 linter。检查 hooks、SKILL.md、AGENTS.md、settings.json、.claude/rules/ 的格式错误、死 glob 模式、缺失字段、broken 引用。参考 agnix 设计。
---

# harness-validate：Claude Code 文件 linter

> 借鉴 agnix（github.com/ef reformation/agnix）的设计思路：
> "lint 规则不会腐烂，文档会。"

## 触发方式

- `/harness-validate` 显式调用
- `/harness-enforce` 执行后自动调用（验证生成的 hook 脚本）
- 在 `harness-upgrade` 时调用（检测 overrides 冲突）

## 目标文件类型

| 文件 | 检查内容 |
|------|---------|
| `skills/*/SKILL.md` | YAML frontmatter 字段、name/description 是否存在、description 是否重复 skill 目录名 |
| `.harness/AGENTS.md` | YAML frontmatter、auto-trigger 规则格式、必填字段完整性 |
| `.claude/settings.json` | JSON 语法、hooks 数组结构、command 路径存在性 |
| `.claude/hooks/*.sh` | bash 语法（shfmt）、exit code 规范、stdin/stdout 契约 |
| `.claude/rules/*.md` | glob 模式是否匹配真实文件、dead pattern 检测 |
| `workflow/dev.md` | YAML 语法、slots.role 是否在 roles 中定义、rules 格式 |
| `context/constraints.md` | enforcement 块 YAML 格式、可执行规则完整性 |

---

## Step 1：扫描文件结构

```
harness-validate 扫描目标：
  .harness/
    ├── AGENTS.md
    ├── framework/version
    ├── context/
    │   ├── module.md
    │   ├── deps.md
    │   ├── arch.md
    │   └── constraints.md
    └── workflow/
        └── dev.md
  .claude/
    ├── settings.json
    ├── hooks/
    │   └── *.sh
    └── rules/
        └── *.md
  skills/
    └── */SKILL.md
```

---

## Step 2：逐类检查

### A. SKILL.md 检查

```bash
# 检查每个 skills/*/SKILL.md
for skill in skills/*/; do
  file="$skill/SKILL.md"
  if [ ! -f "$file" ]; then
    echo "ERROR: $file missing"
    continue
  fi

  # 1. YAML frontmatter
  if ! head -3 "$file" | grep -q "^---"; then
    echo "ERROR: $file missing YAML frontmatter"
  fi

  # 2. required fields
  for field in "name:" "description:"; do
    if ! grep -q "$field" "$file"; then
      echo "ERROR: $file missing '$field'"
    fi
  done

  # 3. name 与目录名一致
  dir_name=$(basename "$skill")
  skill_name=$(grep "^name:" "$file" | awk '{print $2}')
  if [ "$dir_name" != "$skill_name" ]; then
    echo "WARN: $file name '$skill_name' != directory '$dir_name'"
  fi

  # 4. description 不是重复 skill 名
  desc=$(grep "^description:" "$file" | cut -d: -f2- | sed 's/^ *//')
  if echo "$desc" | grep -q "^${dir_name}"; then
    echo "WARN: $file description repeats skill name"
  fi
done
```

### B. settings.json 检查

```bash
# 检查 .claude/settings.json
if [ -f ".claude/settings.json" ]; then
  # 1. JSON 语法
  if ! python3 -c "import json; json.load(open('.claude/settings.json'))" 2>/dev/null; then
    echo "ERROR: .claude/settings.json has invalid JSON"
  fi

  # 2. hooks 数组结构
  # 每个 hook 必须有 name 和 hooks 数组
  # hooks 数组中每项必须有 type 字段

  # 3. command 路径存在性
  # 检查 commands.* 是否指向真实文件
fi
```

### C. Hook 脚本检查

```bash
# 检查 .claude/hooks/*.sh
for hook in .claude/hooks/*.sh; do
  [ -f "$hook" ] || continue

  # 1. shebang
  if ! head -1 "$hook" | grep -q "^#!"; then
    echo "ERROR: $hook missing shebang"
  fi

  # 2. exit 0 或 exit 2 存在（不能裸 exit）
  if ! grep -q "exit [0-2]" "$hook"; then
    echo "WARN: $hook may be missing exit code (should exit 0, 1, or 2)"
  fi

  # 3. PreToolUse hook 必须不输出到 stdout（除非 continue:false）
  # PostToolUse hook 建议 suppressOutput

  # 4. 读取 stdin 的方式（必须用 read，不能用 $1）
  if grep -q '\$1' "$hook" && ! grep -q 'read.*stdin' "$hook"; then
    echo "WARN: $hook uses \$1 but Claude Code hooks pass data via stdin"
  fi
done
```

### D. rules/ glob 模式检查

```bash
# 检查 .claude/rules/*.md 的 glob 是否匹配真实文件
for rule in .claude/rules/*.md; do
  [ -f "$rule" ] || continue

  # 提取 glob 模式（从 --path 后的模式）
  globs=$(grep -oE '--path ["\x27]?[^"'\'' ]+' "$rule" | awk -F'"'"'"'" '{print $2}' | awk '{print $NF}')

  for glob in $globs; do
    if ! compgen -G "$glob" > /dev/null 2>&1; then
      echo "WARN: $rule glob '$glob' matches no files"
    fi
  done
done
```

### E. dev.md workflow 检查

```bash
# 检查 workflow/dev.md
if [ -f ".harness/workflow/dev.md" ]; then
  # 1. slots 中的 role 是否在 roles 中定义
  # 2. slots 中的 skill 是否存在（skills/*/ 目录）
  # 3. rules 格式是否正确（不能有未闭合的引号）
  # 4. enforcement 块 YAML 格式
fi
```

---

## Step 3：输出报告

```
harness-validate 报告

检查文件：14 个
错误：3 个
警告：5 个

ERROR:
  × .claude/settings.json: invalid JSON (line 23)
  × skills/harness-foo/SKILL.md: missing 'description:' field
  × .claude/hooks/pre-commit.sh: missing shebang

WARN:
  ⚠ .claude/rules/api.md: glob 'src/api/**' matches no files
  ⚠ skills/harness-bar/SKILL.md: description repeats skill name
  ⚠ .claude/hooks/post-lint.sh: uses $1 instead of stdin read
  ⚠ workflow/dev.md: slot 'plan' references role 'planner' which is not in roles block
  ⚠ context/constraints.md: enforcement.block has unknown key 'limite' (typo)

建议：
  Fix the 3 ERRORs before committing.
  The 5 WARNs are non-blocking but should be addressed.
```

---

## 退出码

- `0`：无 ERROR（WARNING 可忽略）
- `1`：存在 ERROR
- `2`：无法访问检查目标（权限问题等）

---

## 与 harness-enforce 的关系

```
harness-validate  →  检查文件格式和引用正确性
harness-enforce   →  将正确格式的规则翻译为可执行脚本
```

两者配合：validate 确保文件对，enforce 确保文件能执行。

---

## 快速运行

```bash
/harness-validate
```
