# Forge 框架仓库

## 这是什么

一套 Claude Code skill 集合，为团队大型 monorepo 中的每个模块提供完整的 AI 驱动开发工作流脚手架。

## 目录结构

| 路径 | 说明 |
|-----|-----|
| `framework/version` | 框架版本号，用于升级检测 |
| `templates/module/` | 完整模块 harness 模板（cmd/app 类型） |
| `templates/pkg/` | 轻量包 harness 模板（pkg 类型） |
| `skills/harness-init.md` | 初始化 skill：扫描模块并引导填充 context |
| `skills/harness-dev.md` | 开发主循环 skill：需求到 PR 全流程编排 |
| `skills/harness-review.md` | 双 Agent 对抗 code review skill |
| `skills/harness-upgrade.md` | 框架版本升级 skill |
| `CHANGELOG.md` | 版本变更历史 |

## 修改规范

**修改 skills/（skill 文件）**
- 修改前通知所有团队成员（这些文件会随 harness-upgrade 推送到所有模块）
- 向后兼容原则：新增功能优于修改现有行为
- 每次修改后递增 `framework/version` 并更新 `CHANGELOG.md`

**修改 templates/（模板文件）**
- 模板变更会在团队成员下次运行 `harness-upgrade` 时通过 diff 摘要展示
- `context/` 和 `overrides/` 模板变更不会覆盖开发者已有的文件
- 只有 `framework/` 目录下的内容会被升级覆盖

**不要修改**
- 各模块目录下的 `.harness/context/`（由模块负责人维护）
- 各模块目录下的 `.harness/overrides/`（由模块负责人维护）

## 可用 Skill

安装到 Claude Code 后，以下命令可直接使用：

| 命令 | 功能 |
|-----|-----|
| `/harness-init` | 在当前模块目录初始化 harness（或增量补全 TODO） |
| `/harness-dev` | 进入开发主循环（通常由 AGENTS.md 自动激活） |
| `/harness-review` | 独立触发双 Agent code review |
| `/harness-upgrade` | 升级本模块的 `.harness/framework/` 到最新版本 |
