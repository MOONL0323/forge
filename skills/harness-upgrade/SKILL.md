---
name: harness-upgrade
description: 升级当前模块 .harness/framework/ 到最新版本。三层分离设计保证 context/（开发者托管）和 overrides/ 永不被覆盖。可在 harness-dev 提示有新版本时调用，也可直接执行 /harness-upgrade。
---

# harness-upgrade：框架版本升级

## 触发方式

- harness-dev 检测到新版本并用户选择"现在升级"时自动调用
- 用户直接执行 `/harness-upgrade`

## 前置检查

1. 读取 `.harness/framework/version`（当前版本）
2. 读取 `~/.team-harness/framework/version`（最新版本）
3. 若两者相同 → 提示"已是最新版本"，终止
4. 若 `~/.team-harness/` 不存在 → 提示：

```
⚠️ 找不到框架本地仓库。
请先安装：git clone <team-harness-repo> ~/.team-harness
```

---

## 执行流程

### Step 1：生成变更摘要

```
📦 框架升级：{current} → {latest}

主要变更（来自 ~/.team-harness/CHANGELOG.md）：
  {提取 current 到 latest 版本范围内的条目}

workflow/dev.md 模板变化：
  {如果 framework/workflow/dev.md.tmpl 有变化，展示 diff 摘要；无变化则显示"无变化"}
```

### Step 2：检查 overrides/ 冲突

扫描 `.harness/overrides/` 中的所有文件，与 `~/.team-harness/` 中对应的新版本模板对比：

- 无冲突 → 继续
- 有冲突 → 逐条展示：

```
⚠️ 发现冲突：

  你在 overrides/workflow/dev.md 中自定义了以下内容：
  {冲突片段}

  新版本框架对同一位置做了如下修改：
  {新版本内容}

  如何处理？
    1. 保留我的定制（跳过这条变更）
    2. 采用新版本（覆盖我的定制）
    3. 手动合并（我来编辑）
```

### Step 3：执行升级

用户确认后：
1. 将 `~/.team-harness/framework/` 复制覆盖到 `.harness/framework/`
2. 更新 `.harness/framework/version`
3. 按用户决策处理 overrides/ 冲突
4. 重新生成 `.harness/AGENTS.md`（更新 `framework_version` 字段为新版本号）
5. **不触碰** `.harness/context/` 的任何文件

```
✅ 升级完成：{current} → {latest}

已更新：
  .harness/framework/（全部）
  .harness/AGENTS.md（framework_version 字段）

未改动：
  .harness/context/（你的模块上下文，永远不会被升级覆盖）
  .harness/overrides/（按你的选择处理）

要 git commit 这次升级吗？(y / 不用)
```

## 回滚

升级后如有问题，执行 `git revert` 恢复 `.harness/framework/` 到升级前状态。
版本管理完全依赖 git，不实现额外的回滚机制。
