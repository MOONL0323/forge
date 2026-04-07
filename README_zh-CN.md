[English](./README.md)

---

# Forge

**AI 驱动的开发工作流框架 — Structured Development Workflows for Claude Code**

[![Claude Code](https://img.shields.io/badge/Claude%20Code-Ready-brightgreen)](https://claude.ai/code)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![Stars](https://img.shields.io/github/stars/MOONL0323/forge?style=social)](https://github.com/MOONL0323/forge/stargazers)
[![Skills](https://img.shields.io/badge/16%20Skills-16-brightgreen?style=flat-square&labelColor=233336)](https://github.com/MOONL0323/forge#-skills)
[![CI](https://img.shields.io/github/actions/workflow/status/MOONL0323/forge/ci.yml?style=flat-square&label=CI)](https://github.com/MOONL0323/forge/actions)

> 你描述需求，Forge 自动完成：工作类型识别 → 影响面分析 → 方案设计 → 编码实现 → 对抗审查 → PR 创建。全程多角色 Agent 协作，每一步可配置、可跳过、可量化。

---

## ✨ 特性

| 能力 | 说明 |
|------|------|
| **智能引导** | 从需求描述自动推断工作类型（new-feature / bugfix / refactor / config-change 等），fetch-first 扫描代码，不模糊提问 |
| **影响面分析** | 列出所有变更文件，标注高频文件（30天>5次提交），识别 pkg 接口变更涉及的所有调用方 |
| **流程确认** | 影响面分析后展示完整流程和预算估算，自然语言调整（"跳过 review"、"总预算 $2"） |
| **双 Agent 对抗 Review** | Generator（完整上下文）+ Evaluator（隔离上下文，仅看 diff），3-way verdict（PASS / ITERATE / PIVOT） |
| **Ralph Wiggum 循环** | Fresh context per iteration，story 持久化为 tasks.json，支持 6+ 小时无人值守运行 |
| **机械执行层** | constraints.md → pre-commit hooks + CI scripts + Claude Code hooks，lint 错误内嵌 Fix 指令 |
| **熵管理** | GC 扫描代码漂移 / 文档腐烂 / 架构违规，自动提案编码为 Golden Rules，形成检测→编码→强制闭环 |
| **CI Auto-Fix** | GitHub Actions CI 失败后自动触发 Claude Code 分析日志 + 修复 + 创建 PR |
| **Worktree 隔离** | 每个构建迭代在独立 git worktree 运行，防止上下文污染 |
| **预算管理** | 预防性预算预警 + 透支策略（ask / allow / deny），完成后输出费用汇总 |
| **Live 环境验证** | Playwright 截图 + 7-Phase Design Review（Interaction / Responsive / Visual / A11y / Robust / Code / Console） |
| **Sprint Contract** | 验收标准必须从 UI/API/CLI 可测，不读源码，Planner 产出强制符合此格式 |
| **成本归因** | per-PR token 追踪、作者/审查者归因、团队费用报告、预算预警 |

---

## 🚀 快速开始

### 1. 安装 — 一行命令

```bash
# 最快方式（推荐）
curl -sSL https://raw.githubusercontent.com/MOONL0323/forge/main/install.sh | bash

# 或手动：
git clone https://github.com/MOONL0323/forge.git ~/.forge
cp -r ~/.forge/skills/* ~/.claude/skills/

# 安装 Superpowers（强烈推荐）
/plugin install superpowers@superpowers-marketplace

# 安装 Claude Code
# https://claude.ai/code
```

### 2. 初始化项目

```bash
cd your-monorepo/cmd/my-service
/harness-init
```

AI 静默扫描代码结构，引导你确认 module/deps/arch/constraints，全量初始化约 5 分钟。

### 3. 开始开发

初始化完成后，描述需求即可自动触发完整工作流：

```
你：帮我给白名单功能加个产线维度

AI：📊 影响面分析（静默扫描中...）
    工作类型：new-feature
    直接修改：client.go、config.go（⚠️ 高频文件）
    需协商：pkg/auto-risk-customers-filter → @张三

    为你准备的流程：
      1. 🎩 Planner   — superpowers:brainstorming  (sonnet · $0.50)
      2. 🔨 Builder   — superpowers:subagent-dev    (sonnet · $2.00)
      3. 🔍 Critic    — harness-review              (sonnet · $0.50)
      4. ✅ Finalizer — superpowers:finishing       (haiku  · $0.20)
      估算总预算：$3.20

    这个流程 OK？还是要调整？
你：y

AI：🎯 开始执行...（自动完成所有步骤）
```

---

## 🏗️ 架构概览

```
┌─────────────────────────────────────────────────────┐
│  你：描述需求                                        │
└──────────────────┬──────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────┐
│  harness-onboard                                        │
│  · 工作类型推断（8种类型）                              │
│  · fetch-first 影响面分析                             │
│  · Sprint Contract 生成（黑盒可测）                      │
│  · 动态流程确认 + 预算估算                             │
└──────────────────┬──────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────┐
│  harness-roles — 多角色执行引擎                        │
│                                                      │
│  🎩 Planner ──► 🔨 Builder ──► 🔍 Critic ──► ✅ Finalizer  │
│  (brainstorming)  (subagent-dev)   (harness-review) (finishing) │
│                                                      │
│  每角色 = 独立 fresh subagent + 独立上下文             │
│  每角色 = 独立预算 + 独立工具白名单                   │
└──────────────────┬──────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────┐
│  产出：PR + 文档沉淀 + 技术债记录                      │
└─────────────────────────────────────────────────────┘
```

---

## 📦 Skills

Forge 由 16 个独立 skill 组成，分为三层：

### 框架层（Foundation）

| Skill | 功能 |
|--------|------|
| `/harness-init` | 初始化 `.harness/` 目录，全量/增量/pkg三种模式 |
| `/harness-dev` | 开发主循环 orchestrator |
| `/harness-upgrade` | 框架版本升级，`context/` 永远不被覆盖 |

### 执行层（Execution）

| Skill | 功能 |
|--------|------|
| `/harness-onboard` | 需求分类 + 影响面分析 + Sprint Contract + 流程确认 |
| `/harness-roles` | 多角色引擎：工具白名单、预算管理、透支策略 |
| `/harness-review` | 双 Agent 对抗 Review，3-way verdict，Anti-leniency 评分 |
| `/harness-verify` | Playwright Live 环境验证，7-Phase Design Review |
| `/harness-worktree` | 独立 worktree 构建循环（串行/并行/临时三种模式） |
| `/harness-fix-ci` | CI 失败自动修复 — 分析日志 + 修 + 创建 PR |
| `/harness-cost` | AI 成本归因 — per-PR 追踪、团队报告、预算预警 |

### 自动化层（Automation）

| Skill | 功能 |
|--------|------|
| `/harness-loop` | Ralph Wiggum 自主循环，story 持久化，checkpoint + backpressure |
| `/harness-gc` | 熵管理 + Golden Rules 闭环 + CI Auto-Fix Workflow |
| `/harness-enforce` | constraints.md → hooks + CI scripts + Claude Code hooks |
| `/harness-validate` | Claude Code 文件全面 linter（agnix 风格） |
| `/harness-swarm` | Multi-Agent Swarm + 语义记忆 + 自学习 |

---

## 🎛️ 工作流配置

每个模块的 `.harness/workflow/dev.md` 控制流程：

```yaml
roles:
  planner:   { model: sonnet, budget: $0.50 }
  builder:   { model: sonnet, budget: $2.00 }
  critic:    { model: sonnet, budget: $0.50 }
  finalizer: { model: haiku,  budget: $0.20 }

overdraft: ask  # ask | allow | deny

slots:
  - name: plan
    skill: superpowers:brainstorming
    fallback: brainstorming
    role: planner
    milestone: true

  - name: implement
    skill: superpowers:subagent-driven-development
    fallback: subagent-driven-development
    role: builder
    milestone: true

  - name: review
    skill: harness-review
    role: critic

  - name: finish
    skill: superpowers:finishing-a-development-branch
    fallback: finishing-a-development-branch
    role: finalizer
    milestone: true

rules:
  - "bugfix → skip plan"
  - "config-change → use minimal workflow"
  - "pkg interface change → insert owner checkpoint before plan"

enforcement:
  high-frequency-files:  { behavior: warn, threshold: 5 }
  test-requirement:       { behavior: block, patterns: ["**/service/*.go"] }
  secrets-detection:     { behavior: block }
  tdd-enforcement:       { behavior: warn, enforce_order: test-first }
```

---

## 🔧 目录结构

```
module/
└── .harness/
    ├── AGENTS.md           # Claude Code auto-triggers harness-dev
    ├── framework/
    │   └── version         # 版本号，用于升级检测
    ├── context/            # ← 永久持有，升级时不会被覆盖
    │   ├── module.md       # 模块身份
    │   ├── deps.md        # 依赖
    │   ├── arch.md        # 架构决策
    │   └── constraints.md  # 约束 + enforcement 规则
    ├── workflow/
    │   ├── dev.md         # 工作流配置
    │   └── checklist.md   # 交付检查清单
    └── loop/
        ├── tasks.json      # Ralph Wiggum 任务持久化
        ├── progress.md     # 增量学习日志
        └── archive/        # 历史运行存档
```

---

## ❓ FAQ

**Q: Forge 和 Superpowers 是什么关系？**

Forge 的 planner/builder/finalizer 阶段使用 Superpowers skill（强烈推荐安装）。Forge 专注解决 Superpowers 做不到的部分：需求分类、影响面分析、机械执行、熵管理、CI auto-fix、worktree 隔离。

**Q: 已有 harness 的模块再跑 init 会覆盖内容吗？**

不会。检测到已有 `.harness/` 后进入增量模式，仅处理含 `TODO` 的行。

**Q: 预算怎么估算？**

基于 token 消耗量 × 官方单价，非精确计费。显示均附注"估算"。

**Q: CI 失败后自动修复会循环触发吗？**

不会。workflow 只监听 `workflow_run` 事件，不监听 PR/push，不存在循环。

**Q: 支持 Windows 吗？**

支持。worktree 路径自动使用 `/` 分隔符。

---

## 📄 License

MIT
