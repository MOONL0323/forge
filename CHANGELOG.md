# Changelog

## [Unreleased]

### Added
- `install.sh` — one-command installer (curl | bash)
- `CONTRIBUTING.md` / `CONTRIBUTING_zh-CN.md` — contribution guide
- `CLAUDE.md` — contributor workflow reference
- `.github/ISSUE_TEMPLATE/` — bug report + feature request templates
- `.github/PULL_REQUEST_TEMPLATE.md` — PR template
- `.github/workflows/ci.yml` — skill frontmatter and file-presence checks
- `README.md` + `README_zh-CN.md` — bilingual README (split into two files)
- `.github/SECURITY.md` — security policy
- `.github/CODE_OF_CONDUCT.md` — Contributor Covenant CoC
- `.github/FUNDING.yml` — GitHub Sponsors link
- `.claude/commands/fix-ci.md` — `/fix-ci` command entry point

### New Skills
- `harness-fix-ci` — **CI failure auto-fix killer feature**. Reads failure logs via GitHub API, applies minimal fix, creates PR. Triggered by workflow_run or called directly via `/fix-ci`.
- `harness-cost` — **Team-level AI spend visibility**. Per-PR token tracking, author/reviewer attribution, exportable CSV/JSON reports, budget alerts.

### Improved
- `harness-onboard`: Added **Step 6.5 Sprint Contract Validator Gate** — hard enforcement: Planner output must pass black-box format validation before entering Builder. ACs must describe externally observable behavior (UI/API/CLI/log), no source code references allowed.

## 2.8.0 — 2026-04-07

### 模型面向指令英文化

关键模型指令转英文（注释/描述保持中文）：

- **harness-roles**: role 行为指令（Planner/Builder/Critic/Finalizer）+ per-agent 工具白名单约束全部英文
- **harness-review**: GAN 循环描述、Spec Compliance/Evaluator 输出格式、反宽容评分原则、Context Anxiety 处理全部英文
- **harness-onboard**: Sprint Contract JSON 格式、黑盒可测性原则全部英文
- **harness-loop**: Ralph Wiggum 核心信条 + Story 颗粒度规则全部英文

---

## 2.7.0 — 2026-04-07

### Superpowers 依赖关系显式化

Forge 工作流依赖 Superpowers skill，推荐安装。框架内置 fallback：

- **dev.md template**：slots 改用 `superpowers:brainstorming` 等格式，显式标注 fallback 字段
- **harness-roles**：新增 Skill 解析 + Fallback 逻辑（superpowers:xxx → xxx → 内置 fallback prompt）
- **README.md**：新增 dependency 表格，清晰区分"来自 Superpowers"和"框架内置"的 skill

安装 Superpowers 获得完整功能，不安装仍可运行：
```
/plugin install superpowers@superpowers-marketplace
```

---

## 2.6.0 — 2026-04-07

### 核心改进

- **CI auto-fix workflow 完整实现**：采用官方 `claude-auto-fix-ci-{branch}-{run_id}` 命名，添加 `id-token: write`（OIDC 认证），通过 GitHub API 提取失败 job 详情和日志，新增 `/fix-ci` 命令触发修复，`allowedTools` 限制安全操作范围。
- **反宽容评分原则（Anti-Leniency）**：写入 harness-review Step 2.5。每个维度扣分必须引用具体代码位置（{file}:{line}），给不出可观测证据不能高于 3 分。
- **per-agent 工具配置**：harness-roles 新增 per-agent 工具白名单（Planner: Read/Glob/Grep/WebSearch/Write; Builder: Read/Write/Edit/Glob/Grep/Bash; Evaluator: Read/Write/Bash+Playwright MCP; Finalizer: Read/Write/Bash）、Turn 限制（30/80/40/20）、MCP Server 配置。Evaluator 黑盒约束：禁止读 src/app/lib/components/pages 目录。
- **评估报告格式对齐官方**：Step 3 汇总改为 markdown table 格式，Spec Compliance 含 AC 验收标准逐条检查结果，Evaluator 含每个扣分项的具体代码位置引用。

---

## 2.5.0 — 2026-04-07

### 核心改进

- **Sprint Contract 黑盒可测性**：Planner 产出的验收标准必须从 UI/API/CLI 验证，不能依赖源码检查。每个 AC 必须有 `verifiable_from`（ui/api/cli/log）和具体 `test_method`。未通过 Sprint Contract 验证的 plan 不能进入 Builder 阶段。
- **CI Failure Auto-Fix Workflow**：GitHub Actions CI 失败后自动触发 Claude Code 分析日志 + 修复 + 创建 PR。监听 `workflow_run` 事件，防止循环触发。防止修复失败超过 3 次后停止并通知人工。

---

## 2.4.0 — 2026-04-07

### 核心改进（生产级）

- **harness-swarm**: 语义记忆改用关键词召回 — 命中数 × confidence × log(usage_count) 排序，纯 Bash 实现，无外部依赖。
- **harness-review**: 3-way Verdict — 在 PASS/ITERATE 基础上新增 **PIVOT** 判定（方向性调整）。3次迭代仍失败或 spec_fit < 5 时，从原始 spec 从头重来，并将失败教训写入 swarm 记忆。
- **harness-enforce**: 深度 TDD 强制 — 追踪 git diff 文件顺序，确保 test-first 模式下测试文件变更先于实现文件。检查 git diff --name-only HEAD 的出现顺序。
- **harness-gc**: Golden Rules 闭环 — GC 检测到重复模式时，自动提案编码为 Golden Rule。人工确认后写入 golden-rules.md + 调用 harness-enforce 生成 hook。形成"检测→编码→强制→验证"持续反馈闭环。

---

## 2.3.0 — 2026-04-07

### New Skills

- `harness-verify`: **Live Environment 动态验证** — 用 Playwright 在真实浏览器中运行并截图，7-Phase Design Review（Interaction/Responsiveness/Visual/A11y/Robustness/Code/Console），响应式视口测试（mobile/tablet/laptop），WCAG 可访问性检查。替换纯静态 diff 分析，用视觉证据说话。Anthropic Quickstart "Live Environment First" 方法论实现。
- `harness-worktree`: **隔离 Worktree 构建循环** — 每个 Builder/Generator 构建轮次使用独立 git worktree，三种模型（串行/并行/临时），review 通过后合并回 main。防止迭代之间的状态泄露和上下文污染。Generator 和 Evaluator 的 worktree 完全隔离。

### 填补的核心差距

| 原本缺失 | 现在实现 |
|---------|---------|
| 无 Live 环境验证 | harness-verify：Playwright + 截图 + 7-Phase Review |
| 无 Worktree 隔离 | harness-worktree：每次构建在干净 worktree 运行 |

---

## 2.2.0 — 2026-04-07

### New Skills

- `harness-validate`: Claude Code 文件全面 linter — 检查 hooks/SKILL.md/AGENTS.md/settings.json/rules/ 的格式错误、死 glob 模式、缺失字段、broken 引用。参考 agnix 设计，lint 规则不腐烂原则。
- `harness-swarm`: 自学习 Multi-Agent Swarm — 带向量语义记忆的并行 agent 系统。从历史任务中持续学习团队偏好，协调多个 subagent 并行工作，支持语义检索已积累的经验。借鉴 Ruflo 模式。

### 与旧版对比

| 能力 | harness-loop | harness-swarm |
|------|-------------|---------------|
| 执行模型 | 串行 story 迭代 | 并行 agent swarm |
| 记忆 | 无 | 向量语义记忆 |
| 学习 | 无 | 从历史中持续改进 |
| 协调 | 无 | agent 间通信 |

---

## 2.1.0 — 2026-04-07

Major additions: mechanical enforcement, Ralph loop, entropy management, and GAN-inspired dual reviewer.

### New Skills

- `harness-enforce`: Mechanical enforcement layer — translates constraints.md rules into lint scripts, pre-commit hooks, CI checks, **and Claude Code hooks (`.claude/hooks/`)**. Implements OpenAI's core Harness Engineering principle: "lint rules don't rot, documents do."
  - Added `tdd-enforcement` rule: enforces test-first development with PreToolUse hook
  - Added `auto-hooks` generation: automatically creates `.claude/hooks/` scripts from enforcement config
  - Supports `PreToolUse` (block secrets, protect files) and `PostToolUse` (lint feedback, test checks) hooks
- `harness-loop`: Ralph Wiggum autonomous loop — persistent task state (tasks.json), fresh-context iteration per story, checkpoint mechanism, and backpressure gates. Enables 6+ hour unattended autonomous execution.
- `harness-gc`: Entropy management / garbage collection — scans for code drift, documentation staleness, architectural violations, and generates repair PRs.

### Improved Skills

- `harness-review`: **Truly parallel dual reviewers** — Generator (Spec Compliance) and Evaluator now dispatch as concurrent independent subagents, not sequential. Ensures neither blocks the other. GAN-inspired iterative loop with max 3 iterations, pass thresholds (Spec Compliance ≥ 8, Evaluator ≥ 7).
- `harness-roles`: Added preventive budget estimation before subagent dispatch (not just reactive post-mortem). Now estimates based on skill type before spending. Clarified model selection is guidance-only (cannot be enforced by Claude Code Agent tool).
- `harness-onboard`: Added work types: `config-change`, `docs-only`, `dependency-upgrade` (was missing from previous taxonomy).

### Template Changes

- `workflow/dev.md.tmpl`: Added `enforcement:` YAML block for harness-enforce integration. Removed hard superpowers dependency — now recommends installation but provides fallback prompts. Added workflow mode documentation for /debug, /research, /refactor, /config, /docs.
- `claude-plugin.json`: Added three new skills to manifest.

### Breaking Changes

- None (all changes are additive)

---

## 2.0.0 — 2026-04-07

Major upgrade: intelligent guided framework with hat system and pluggable slots.

### New Skills
- `harness-onboard`: Work type inference, impact analysis, dynamic slot manipulation, flow confirmation
- `harness-roles`: Hat system, multi-role subagent dispatch, token-based cost estimation, overdraft policy

### Changed Skills
- `harness-dev`: Rewritten as lightweight coordinator; delegates to harness-onboard and harness-roles

### Template Changes
- `workflow/dev.md.tmpl`: New YAML-in-Markdown format with `roles`, `overdraft`, `slots`, `rules` sections

### Breaking Changes
- `workflow/dev.md` format is incompatible with v1. Run `/harness-upgrade` to migrate.

---

## 1.0.0 — 2026-04-07

Initial release.

### Skills
- `harness-init`: Initialize a module or pkg Harness via guided conversation
- `harness-dev`: Full development loop with superpowers skill orchestration
- `harness-review`: Dual-agent adversarial code review (Claude + Codex)
- `harness-upgrade`: Non-blocking framework version upgrade

### Templates
- Module template: AGENTS.md + context/ + workflow/
- Pkg template: contract.md + constraints.md + owner.md
