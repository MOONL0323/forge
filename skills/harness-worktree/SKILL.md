---
name: harness-worktree
description: 每个 Builder/Generator 构建轮次使用独立 git worktree，隔绝上下文污染。构建前创建干净分支，review 通过后合并回主分支。防止迭代之间的状态泄露。
---

# harness-worktree：隔离 Worktree 的构建循环

> 核心原则：每个构建迭代在干净的 worktree 中运行。
> 上一轮的 Builder 上下文不影响下一轮。
> Generator 的 worktree 与 Evaluator 的 worktree 完全隔离。

## 与 harness-loop 的区别

| 维度 | harness-loop | harness-worktree |
|------|-------------|-----------------|
| 上下文隔离 | 无（同一个目录） | 有（独立 worktree） |
| 迭代间状态 | 累积 | 每次全新 |
| branch 模型 | 单分支多次 commit | 多 branch 每次重建 |
| 适合场景 | 长时间无人值守 | 高质量构建验证 |

---

## 核心概念

### 为什么需要 worktree 隔离？

```
问题：Builder 在同一目录工作
  → 上一轮的未完成代码干扰下一轮
  → git status 显示上次残留的变更
  → lint 报告上次遗留的错误
  → Reviewer 看到的是混合上下文

解决：每个构建轮次用独立 worktree
  → 干净的文件系统状态
  → 上一轮的东西完全不存在
  → Reviewer 只看到本次的变更
```

### 三种 worktree 模型

```
模型 A — 串行 worktree（简单）
  main → worktree-1 (build 1) → merge → worktree-2 (build 2) → merge

模型 B — 并行 worktree（推荐）
  main → worktree-1 (build 1) ← 并行 →
  main → worktree-2 (build 2) ←        ↗
  main → worktree-3 (build 3) ←────────┘
  全部 merge 回 main

模型 C — 临时 worktree（最高隔离）
  每次构建前新建 worktree，构建后立即删除
  不保留中间状态，每次都是全新克隆
```

---

## 触发方式

```
用户：「用隔离环境构建这个需求」
用户：「每个迭代用独立 branch」
用户：「干净 worktree 跑一遍」

自动触发：
  - harness-review 迭代超过 2 次仍失败
  - 高风险重构（涉及多个高频变更文件）
  - 涉及 pkg 公开接口的重大变更
```

---

## Step 1：分析构建范围

```bash
# 获取当前变更文件列表
git diff --name-only main...HEAD

# 识别构建范围
STAGED=$(git diff --cached --name-only)
UNSTAGED=$(git diff --name-only)
UNTRACKED=$(git ls-files --others --exclude-standard)

echo "变更范围："
echo "  已暂存：$STAGED"
echo "  未暂存：$UNSTAGED"
echo "  新文件：$UNTRACKED"
```

---

## Step 2：创建隔离 worktree

### 模型 A — 串行 worktree

```bash
# 确保 main 最新
git fetch origin main
git checkout main

# 创建新 branch + worktree
BRANCH_NAME="build/$(date +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD)"
WORKTREE_PATH="../.worktrees/$BRANCH_NAME"

# 创建 worktree
git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"

echo "Worktree 创建：$WORKTREE_PATH"
echo "Branch：$BRANCH_NAME"

# 在 worktree 中同步最新代码
cd "$WORKTREE_PATH"
git fetch origin main
git merge origin/main --no-edit

# 记录到状态文件
cat > .harness/worktree/current.json <<EOF
{
  "branch": "$BRANCH_NAME",
  "path": "$WORKTREE_PATH",
  "created": "$(date -Iseconds)",
  "parent_commit": "$(git rev-parse HEAD)",
  "model": "serial"
}
EOF

echo "✅ Worktree 隔离就绪：$BRANCH_NAME"
```

### 模型 B — 并行 worktree（同一功能多角度构建）

```bash
# 从 main 同时创建多个 worktree
for i in 1 2 3; do
  BRANCH="parallel-$i/$(date +%Y%m%d)"
  PATH="../.worktrees/$BRANCH"
  git worktree add "$PATH" -b "$BRANCH" main
  echo "✅ Worktree $i: $PATH"
done
```

### 模型 C — 临时 worktree（最高隔离，每次全新）

```bash
# 临时 worktree：构建后立即删除，不保留中间状态
TEMP_DIR=$(mktemp -d "/tmp/harness-worktree-XXXXXX")
TEMP_BRANCH="temp/$(date +%s)"

git worktree add "$TEMP_DIR" -b "$TEMP_BRANCH"

# 在其中工作...

# 完成后：保留构建结果，删除临时 worktree
# 但保留结果 commit 不删除（这样 worktree 删了 commit 还在）
git worktree remove "$TEMP_DIR" --force

echo "✅ 临时 worktree 已清理"
```

---

## Step 3：在隔离 worktree 中构建

```bash
# 切换到 worktree
cd "$WORKTREE_PATH"

# 确认干净状态（无残留变更）
if [ -n "$(git status --porcelain)" ]; then
  echo "⚠️  Worktree 不干净，先 stash"
  git stash
fi

# 同步最新 main
git merge origin/main --no-edit

# 开始构建
echo "🎯 开始构建（隔离环境）"
# ... 构建步骤 ...
```

---

## Step 4：构建完成 → Review

```bash
# 在 worktree 中运行 harness-review
cd "$WORKTREE_PATH"
# harness-review ...

# Review 通过后，合并回 main
if [ "$REVIEW_STATUS" = "PASS" ]; then
  git checkout main
  git merge "$BRANCH_NAME" --no-ff -m "Merge $BRANCH_NAME"
  git branch -d "$BRANCH_NAME"
  git worktree remove "$WORKTREE_PATH" --force
  echo "✅ 构建结果已合并到 main"
else
  echo "⚠️  Review 未通过，保留 worktree 供调试"
  echo "Worktree 路径：$WORKTREE_PATH"
  echo "Branch：$BRANCH_NAME"
fi
```

---

## Step 5：状态管理

```bash
# 查看所有 worktree
git worktree list

# 清理已完成的 worktree
git worktree prune

# 查看 harness worktree 状态
cat .harness/worktree/current.json

# 清理所有 harness worktree（紧急清理用）
for wt in $(git worktree list --porcelain | grep "^worktree" | awk '{print $2}'); do
  if echo "$wt" | grep -q "worktrees"; then
    echo "🧹 清理：$wt"
    git worktree remove "$wt" --force 2>/dev/null
  fi
done
```

---

## 与 harness-review 的整合

```
harness-review 开始时：
  ↓
检查是否启用了 worktree 隔离
  ↓
如果是：worktree 已准备好，直接在其中运行
  ↓
Generator 在 worktree 构建
  ↓
Evaluator 在独立上下文（无 worktree）审查 diff
  ↓
Review 通过 → merge 回 main
Review 失败 → 保留 worktree 供调试
  ↓
下次迭代：新建 worktree（上次 worktree 保留为调试用）
```

---

## 目录结构

```
.harness/worktree/
├── current.json       # 当前 worktree 状态
├── history.json       # 历史 worktree 记录
└── archive/           # 调试用保留的 worktree 快照
```

**current.json 格式**：
```json
{
  "branch": "build/20260407-143022-a1b2c3d",
  "path": "/path/to/.worktrees/build/20260407-143022-a1b2c3d",
  "created": "2026-04-07T14:30:22Z",
  "parent_commit": "a1b2c3d",
  "status": "building|reviewing|merged|failed",
  "model": "serial|parallel|temp"
}
```

**history.json 格式**：
```json
[
  {
    "branch": "build/20260407-143022-a1b2c3d",
    "status": "merged",
    "duration_seconds": 342,
    "iterations": 2,
    "merged_at": "2026-04-07T14:36:04Z"
  }
]
```

---

## 快速运行

```bash
# 启动隔离构建
/harness-worktree --start

# 查看当前 worktree 状态
/harness-worktree --status

# 合并到 main（review 通过后）
/harness-worktree --merge

# 清理所有 worktree
/harness-worktree --cleanup

# 紧急清理（删所有 harness worktree）
/harness-worktree --prune
```

---

## 注意事项

- **Windows 兼容**：worktree 路径使用 `/` 而非 `\`
- **Parallel 模式慎用**：多个 worktree 同时修改同一文件会导致合并冲突
- **临时模式最干净**：适合高风险重构，每次全新开始
- **不超过 5 个 worktree**：git 默认限制，多了需要清理
