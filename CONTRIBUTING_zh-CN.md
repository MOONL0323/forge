# 参与贡献 Forge

[English](./CONTRIBUTING.md)

---

## 行为准则

Forge 遵循 [Contributor Covenant](https://www.contributor-covenant.org/)。
所有贡献者须保持尊重、建设性和协作的态度。

---

## 贡献方式

- **报告 Bug** — 使用 GitHub Issues 的 Bug Report 模板
- **功能建议** — 发起 Discussion 或使用 Feature Request 模板
- **改进文档** — README、SKILL.md 和模板改进的 PR 均欢迎
- **提交新 Skill** — `skills/` 下新增 skill 须遵循 SKILL.md 格式
- **代码审查** — 审查 open PR，重点关注安全性和非回归

---

## 开发环境

```bash
# 克隆你的 fork
git clone https://github.com/YOUR_USERNAME/forge.git
cd forge

# 创建测试模块
mkdir -p /tmp/test-module && cd /tmp/test-module
git init

# 在 Claude Code 中运行（链接本地 skills 后）：
# /harness-init
```

---

## Skill 格式

每个 skill 位于 `skills/<name>/SKILL.md`，必须包含：

```yaml
---
name: skill-name          # kebab-case，唯一
description: 一句话描述 # 在 Claude Code /help 和 skill marketplace 中展示
---
```

所有现有 skill 使用 **中文注释 + 英文模型指令**。
修改或新增 skill 时保持此约定。

---

## Pull Request 流程

### 1. 分支命名

```
feat/<简短描述>
fix/<issue编号>
docs/<领域>
```

### 2. 提交 PR 前

- [ ] 如有用户可见变更，更新 `framework/version`
- [ ] 在 `CHANGELOG.md` 的 `[Unreleased]` 下添加条目
- [ ] 新增 skill 填写 frontmatter（`name`、`description`）
- [ ] 无对现有 skill 接口的破坏性变更（除非同步版本升级）

### 3. PR 描述

使用 PR 模板。无模板时包含：
- **做了什么** 及 **为什么**
- **如何测试**（如有）
- **破坏性变更**（如有）

### 4. 审查优先级

PR 在 1 周内审查。优先级：
1. 安全 / 安全性回归
2. 无版本升级的破坏性变更
3. 文档准确性
4. 其他

---

## 破坏性变更政策

- 破坏性变更 = 任何改变现有 skill 接口行为的修改
- 破坏性变更需小版本升级（`x.Y.z`）并在 CHANGELOG.md 说明
- `context/` 文件（`.harness/context/*`）**永远不会被** Forge 升级覆盖——不要在那里添加破坏性变更

---

## 许可证

参与贡献即表示你同意你的贡献将使用 MIT 许可证。
