[简体中文](./README_zh-CN.md)

---

# Forge

**AI-Driven Development Workflow Framework — Structured Engineering for Claude Code**

[![Claude Code](https://img.shields.io/badge/Claude%20Code-Ready-brightgreen)](https://claude.ai/code)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![Stars](https://img.shields.io/github/stars/MOONL0323/forge?style=social)](https://github.com/MOONL0323/forge/stargazers)

> Describe intent. Forge handles the rest: requirement classification → impact analysis → design → implementation → adversarial review → PR creation. Multi-agent collaboration with full observability, configurability, and quantifiability at every step.

---

## ✨ Features

| Capability | Description |
|------------|-------------|
| **Smart Bootstrapping** | Infers work type from natural language (new-feature / bugfix / refactor / config-change / docs-only / dependency-upgrade / new-module). No manual selection required. |
| **Impact Analysis** | Lists all affected files, flags high-frequency files (>5 commits in 30 days), identifies all callers of changed pkg interfaces. |
| **Flow Confirmation** | Shows complete workflow + budget estimate after impact analysis. Natural language adjustments ("skip review", "budget cap $2"). |
| **Dual-Agent Adversarial Review** | Generator (full context) + Evaluator (isolated context, diff only). 3-way verdict: PASS / ITERATE / PIVOT. Anti-leniency scoring discipline. |
| **Ralph Wiggum Loop** | Fresh context per story iteration. tasks.json persistence. Supports 6+ hour autonomous runs. |
| **Mechanical Enforcement** | constraints.md → pre-commit hooks + CI scripts + Claude Code hooks. Every lint error embeds Fix instructions. |
| **Entropy Management** | GC scans code drift, doc rot, arch violations. Auto-proposes Golden Rules encoding. Detection → Encoding → Enforcement → Verification loop. |
| **CI Auto-Fix** | GitHub Actions `workflow_run` trigger. Claude Code analyzes failure logs + fixes + creates PR. Loop-safe. |
| **Worktree Isolation** | Each build iteration runs in an isolated git worktree. Three models: serial / parallel / temp. |
| **Budget Management** | Preventive warning + reactive warning. Three overdraft policies: ask / allow / deny. |
| **Live Environment Verification** | Playwright screenshots + 7-Phase Design Review (Interaction / Responsiveness / Visual / A11y / Robust / Code / Console). |
| **Sprint Contracts** | Acceptance criteria must be verifiable from UI/API/CLI. No source code reading. Planner output must conform. |

---

## 🚀 Quick Start

### 1. Install — One Command

```bash
# The fast way (recommended)
curl -sSL https://raw.githubusercontent.com/MOONL0323/forge/main/install.sh | bash

# Or manually:
git clone https://github.com/MOONL0323/forge.git ~/.forge
cp -r ~/.forge/skills/* ~/.claude/skills/

# Install Superpowers (strongly recommended)
# /plugin install superpowers@superpowers-marketplace

# Install Claude Code
# https://claude.ai/code
```

### 2. Initialize a Module

```bash
cd your-monorepo/cmd/my-service
/harness-init
```

AI scans your codebase silently, then walks you through module / deps / arch / constraints confirmation. Full init takes ~5 minutes.

### 3. Start Building

After init, just describe what you want:

```
You: Add a product-line dimension to the whitelist feature

AI: 📊 Impact Analysis (scanning silently...)
    Work type: new-feature
    Direct changes: client.go, config.go (⚠️ high-frequency)
    Needs negotiation: pkg/auto-risk-customers-filter → @zhangsan

    Your workflow:
      1. 🎩 Planner   — superpowers:brainstorming   (sonnet · $0.50)
      2. 🔨 Builder   — superpowers:subagent-dev   (sonnet · $2.00)
      3. 🔍 Critic    — harness-review             (sonnet · $0.50)
      4. ✅ Finalizer — superpowers:finishing      (haiku  · $0.20)
    Estimated budget: $3.20

    OK? Or want to adjust?
You: y

AI: 🎯 Executing... (automatically completes all steps)
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│  You: Describe intent                                │
└──────────────────┬──────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────┐
│  harness-onboard                                     │
│  · Work type inference (8 types)                    │
│  · fetch-first impact analysis                       │
│  · Sprint Contract generation (black-box testable) │
│  · Dynamic workflow confirmation + budget estimate   │
└──────────────────┬──────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────┐
│  harness-roles — Multi-Role Execution Engine        │
│                                                       │
│  🎩 Planner ──► 🔨 Builder ──► 🔍 Critic ──► ✅ Finalizer │
│  (brainstorming)   (subagent-dev)    (harness-review)  │
│                                                       │
│  Each role = fresh subagent + isolated context       │
│  Each role = independent budget + tool allowlist     │
└──────────────────┬──────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────┐
│  Output: PR + Documentation + Technical Debt Record   │
└─────────────────────────────────────────────────────┘
```

---

## 📦 Skills

Forge is composed of 16 independent skills across three layers:

### Foundation Layer

| Skill | Function |
|-------|----------|
| `/harness-init` | Initialize `.harness/` directory (full / incremental / pkg mode) |
| `/harness-dev` | Development orchestrator |
| `/harness-upgrade` | Framework upgrade, `context/` never overwritten |

### Execution Layer

| Skill | Function |
|-------|----------|
| `/harness-onboard` | Requirement classification + impact analysis + Sprint Contract + flow confirmation |
| `/harness-roles` | Multi-role engine: tool allowlists, budget management, overdraft policies |
| `/harness-review` | Dual-agent adversarial review, 3-way verdict, anti-leniency scoring |
| `/harness-verify` | Playwright live verification, 7-Phase Design Review |
| `/harness-worktree` | Isolated worktree build cycles (serial / parallel / temp models) |
| `/harness-fix-ci` | CI failure auto-fix — reads logs, applies fix, creates PR |
| `/harness-cost` | Team-level AI spend visibility — per-PR tracking, attribution, reports |

### Automation Layer

| Skill | Function |
|-------|----------|
| `/harness-loop` | Ralph Wiggum autonomous loop, story persistence, checkpoint + backpressure |
| `/harness-gc` | Entropy management + Golden Rules feedback loop + CI Auto-Fix Workflow |
| `/harness-enforce` | constraints.md → hooks + CI scripts + Claude Code hooks |
| `/harness-validate` | Claude Code file linter (agnix-style) |
| `/harness-swarm` | Multi-Agent Swarm + semantic memory + self-learning |

---

## 🎛️ Workflow Configuration

Each module's `.harness/workflow/dev.md` controls the workflow:

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

## 🔧 Directory Structure

```
module/
└── .harness/
    ├── AGENTS.md           # Claude Code auto-triggers harness-dev
    ├── framework/
    │   └── version         # Version number, used for upgrade detection
    ├── context/            # ← Permanently owned, never overwritten on upgrade
    │   ├── module.md       # Module identity
    │   ├── deps.md        # Dependencies
    │   ├── arch.md        # Architecture decisions
    │   └── constraints.md # Constraints + enforcement rules
    ├── workflow/
    │   ├── dev.md         # Workflow configuration
    │   └── checklist.md   # Delivery checklist
    └── loop/
        ├── tasks.json      # Ralph Wiggum task persistence
        ├── progress.md     # Incremental learning log
        └── archive/        # Historical run archive
```

---

## ❓ FAQ

**Q: What's the relationship between Forge and Superpowers?**

Forge uses Superpowers skills for the planner/builder/finalizer phases (strongly recommended to install). Forge focuses on what Superpowers doesn't cover: requirement classification, impact analysis, mechanical enforcement, entropy management, CI auto-fix, and worktree isolation.

**Q: Will running init on an existing module overwrite content?**

No. Detecting an existing `.harness/` triggers incremental mode — only processes lines containing `TODO`. Everything else is preserved.

**Q: How is budget estimated?**

Based on token usage × official pricing. Not a precise meter. All amounts are marked "estimated."

**Q: Will CI auto-fix create infinite loops?**

No. The workflow only listens to `workflow_run` events, not PR/push events. Loop-safe by design.

**Q: Does it support Windows?**

Yes. Worktree paths automatically use `/` separators.

---

## 📄 License

MIT
