# Forge 框架仓库

## 这是什么

一套 Claude Code skill 集合，为团队大型 monorepo 中的每个模块提供完整的 AI 驱动开发工作流脚手架。

## 目录结构

| 路径 | 说明 |
|-----|-----|
| `framework/version` | 框架版本号，用于升级检测 |
| `templates/module/` | 完整模块 harness 模板（cmd/app 类型） |
| `templates/pkg/` | 轻量包 harness 模板（pkg 类型） |
| `skills/harness-*/SKILL.md` | 16 个独立 skill（Foundation / Execution / Automation 三层） |
| `CHANGELOG.md` | 版本变更历史 |
| `CONTRIBUTING.md` | 贡献指南 |
| `install.sh` | 一键安装脚本 |
| `.github/` | Issue/PR 模板 + CI workflow |

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

## 可用 Skill（全部 16 个）

安装到 Claude Code 后，以下命令可直接使用：

### Foundation 层
| 命令 | 功能 |
|-----|-----|
| `/harness-init` | 初始化 `.harness/` 目录（全量 / 增量 / pkg 模式）|
| `/harness-dev` | 开发主循环 orchestrator |
| `/harness-upgrade` | 框架版本升级，`context/` 永远不被覆盖 |

### Execution 层
| 命令 | 功能 |
|-----|-----|
| `/harness-onboard` | 需求分类 + 影响面分析 + Sprint Contract + 流程确认 |
| `/harness-roles` | 多角色引擎：工具白名单、预算管理、透支策略 |
| `/harness-review` | 双 Agent 对抗 Review，3-way verdict，Anti-leniency 评分 |
| `/harness-verify` | Playwright Live 环境验证，7-Phase Design Review |
| `/harness-worktree` | 独立 worktree 构建循环（串行 / 并行 / 临时三种模式）|
| `/harness-fix-ci` | CI 失败自动修复 — 分析日志 + 修 + 创建 PR |
| `/harness-cost` | AI 成本归因 — per-PR 追踪、团队报告、预算预警 |

### Automation 层
| 命令 | 功能 |
|-----|-----|
| `/harness-loop` | Ralph Wiggum 自主循环，story 持久化，checkpoint + backpressure |
| `/harness-gc` | 熵管理 + Golden Rules 闭环 + CI Auto-Fix Workflow |
| `/harness-enforce` | constraints.md → hooks + CI scripts + Claude Code hooks |
| `/harness-validate` | Claude Code 文件全面 linter（agnix 风格）|
| `/harness-swarm` | Multi-Agent Swarm + 语义记忆 + 自学习 |
