---
name: harness-review
description: 双 Agent 对抗 Review + GAN 启发式评分。基于 Anthropic Labs 的 Generator/Evaluator 分离原则：Generator（内部视角，有完整上下文）负责 spec compliance；Evaluator（对抗视角，只有 diff+需求）负责独立评价。两者都输出结构化评分，不只是 MUST FIX/PASS。参考：harness-design-long-running-apps (Anthropic, 2026-03-24)。
---

# harness-review：双 Agent 对抗 Review + 评分

> 参考：Anthropic Labs — "Harness design for long-running application development"
> 核心原则：Generator（实现者）和 Evaluator（评判者）必须分离。
> 自我评价 = 过度宽容。独立 Evaluator 的批评远比让 Generator 自我批判容易。

---

## 触发方式

**流程内调用**：harness-dev 在 code-review 步骤自动调用。

**独立调用**：用户执行 `/harness-review`，需提供：
1. 需求描述（必填）
2. branch 名或 commit range（必填）
3. constraints.md（当前目录有 `.harness/` 则自动读取）

---

## GAN-Inspired Feedback Loop

```
Generator produces code
      ↓
Evaluator grades independently (with specific scores)
      ↓
Generator iterates based on scores (if MUST FIX exists)
      ↓
Evaluator re-grades
      ↓
Loop until pass or user intervenes
```

This is NOT a one-shot review. It is an **iterative improvement loop**.

---

## Step 1：准备 Review 材料

**生成 diff：**
```bash
git diff {base_branch}...HEAD
# 或
git diff {commit_range}
```

**diff 处理规则（按文件分批，不做粗暴截断）：**

Step A：统计
```bash
git diff {base}...HEAD --stat
```

Step B：分批策略（目标每批 ~400 行）
- 500 行以内：完整使用
- 超过 500 行：按文件分组，每批不超过 400 行
- 大文件（单文件超 400 行）：按 hunk 截取关键变更区域
- 告知用户分了几批

**分批输出格式：**
```
[Review Batch 1/3 — {文件列表}，共 ~{N} 行]
[DIFF_BATCH_1]
---
[Review Batch 2/3 — {文件列表}，共 ~{N} 行]
[DIFF_BATCH_2]
```

**读取约束：** `.harness/context/constraints.md`（不存在则为空）

---

## Step 2：派发两个 Reviewer（真正并发）

> **关键原则**：Generator 和 Evaluator 必须同时启动，不能串行。
> 两者各自独立 subagent，有独立上下文，同时运行，互不等待。
> 最后才汇总评分。

### 并发派发（不要等一个完成再启动另一个）

**同时**使用 Agent tool 派发两个 subagent：

```
Agent "Generator" — 内部 Reviewer（Spec Compliance）
Agent "Evaluator"  — 对抗 Reviewer（Evaluator）
```

等待两个 agent 都返回后，进入 Step 3 汇总。

**提示**：两个 Agent 是独立调用，不要在 prompt 中等待对方的输出。
Generator 和 Evaluator 必须同时运行，不能串行。

---

### 内部 Reviewer — Generator 视角（Spec Compliance）

携带完整信息：需求描述 + 影响面分析 + 设计方案 + 实施计划 + diff + constraints.md

**Spec Compliance Review Dimensions:**

1. Does the implementation match the design intent?
2. Are any steps from the implementation plan missing?
3. Is boundary case coverage complete?
4. Does it conflict with any constraints in constraints.md?
5. Is the code readable and maintainable?

**Output format (strictly follow):**

```
## Spec Compliance Report

### Scores (1-10)

### spec_fit: {N}/10
Does implementation match design? Deduct for: {description}

### completeness: {N}/10
Is functionality complete? Missing parts: {description}

### boundary_cases: {N}/10
Boundary case coverage: {description}

### constraints_aligned: {N}/10
Alignment with constraints: {description}

### Overall: {avg}/10

### Issues

MUST FIX: [serious spec violations — must fix before proceeding]
SUGGEST: [improvements, non-blocking]
QUESTION: [clarifications needed]
[If all dimensions ≥ 8 with no MUST FIX:]
PASS — Spec Compliance passed
```

---

### 对抗 Reviewer — Evaluator 视角（隔离评分）

故意只给：diff + 需求 + constraints。**不给设计方案**。

这是 Anthropic 说的"分离 Generator 和 Evaluator"的核心：
Evaluator 不知道实现者打算怎么做的，只看最终结果。

**Evaluation Dimensions:**

| Dimension | Weight | Question |
|-----------|--------|---------|
| correctness | highest | Does the code correctly implement the requirement? Any logic bugs? |
| readability | highest | Can you understand it on first read? Are names self-explanatory? |
| maintainability | medium | Is structure clear? Any obvious duplication? |
| change_safety | medium | Will this break existing functionality? Is the interface backward compatible? |
| no_slop | reference | Any AI slop patterns? (Template code, unchanged defaults, hardcoded magic numbers) |

**Output format (strictly follow):**

```
## Evaluator Report

### Scores (1-10)

### correctness: {N}/10
Evidence: {specific issue with file:line}

### readability: {N}/10
Evidence: {how it reads on first pass}

### maintainability: {N}/10
Evidence: {structure analysis}

### change_safety: {N}/10
Evidence: {potential breakage assessment}

### no_slop: {N}/10
Evidence: {template/default/AI smell check}

### Overall: {avg}/10

### Issues

MUST FIX: [description]
SUGGEST: [description]
QUESTION: [description]

### Scoring Rationale
For each dimension, cite specific code location and reason for deduction.
```

### 评分理由（详细说明为什么扣分）
{给出每项扣分的具体代码位置和原因}

[如果 Overall ≥ 7 且无 MUST FIX：]
PASS — Evaluator 通过
```

**降级处理**：若 codex-plugin-cc 不可用，降级为 Claude subagent，标注 `⚠️ Codex 不可用，已降级为 Claude Evaluator`。

---

## Step 2.5：Anti-Leniency Scoring Discipline

> **Scoring rule from Anthropic eval-criteria.md:**
> "If you cannot point to specific observable evidence of quality, do not score above 3."
> "3 is the baseline, not a consolation prize."

**Scoring discipline**:
```
When scoring, you MUST be able to cite specific, observable evidence.

❌ Wrong: "Code looks okay" → score 6
✅ Right: "Function names are self-explanatory, logic flow is clear, no magic numbers"
   → Has evidence → can score 7+

❌ Wrong: "Implementation is fairly complete" → score 5
✅ Right: "All ACs have corresponding implementation, boundary cases have test coverage"
   → Has evidence → can score 7+

For each deduction, you MUST:
  1. Cite specific code line or behavior ("at {file}:{line}, {specific issue}")
  2. Explain why it caused the deduction
  3. Never say "just doesn't feel right"
```

### Spec Compliance Report（Generator 视角）

| 维度 | 分数 | 证据 |
|------|------|------|
| spec_fit | {N}/10 | {具体证据} |
| completeness | {N}/10 | {具体证据} |
| boundary_cases | {N}/10 | {具体证据} |
| constraints_aligned | {N}/10 | {具体证据} |
| **Overall** | **{avg}/10** | — |

**验收标准检查结果**：

| AC ID | 状态 | 验证方法和结果 |
|-------|------|---------------|
| AC-1 | ✅ PASS / ❌ FAIL | {验证方法}: {结果} |
| AC-2 | ✅ PASS / ❌ FAIL | {验证方法}: {结果} |

**Issues**：

- **MUST FIX**: [严重问题]
- **SUGGEST**: [建议改进]
- **QUESTION**: [需要澄清]

---

### Evaluator Report（对抗视角）

| 维度 | 分数 | 证据 |
|------|------|------|
| correctness | {N}/10 | {file}:{line} — {具体问题} |
| readability | {N}/10 | {file}:{line} — {具体问题} |
| maintainability | {N}/10 | {file}:{line} — {具体问题} |
| change_safety | {N}/10 | {file}:{line} — {具体问题} |
| no_slop | {N}/10 | {是否有模板/默认/AI 生成气味} |
| **Overall** | **{avg}/10** | — |

**反宽容检查**：每个维度 ≤ 3 时，必须有具体可观测证据。{维度}={N} 的证据：{...}

**Issues**：

- **MUST FIX**: [严重问题]
- **SUGGEST**: [建议改进]
- **QUESTION**: [需要澄清]

---

## Step 4：3-Way Verdict 判定

> **关键设计**：不是只有 PASS/ITERATE，还有第三种可能——PIVOT。
> PIVOT = 方向错了，不是实现质量问题。从原始 spec 重新开始。

### 三种判定结果

| 判定 | 条件 | 行为 |
|------|------|------|
| **PASS** | Spec ≥ 8 且 Evaluator ≥ 7 且无 MUST FIX | 进入下一步 |
| **ITERATE** | 存在 MUST FIX 或 Spec < 8 或 Evaluator < 7 | Generator 修复后重评（最多3次） |
| **PIVOT** | 3次 ITERATE 后仍失败，或 spec_fit < 5 | 回到原始需求，从头重新分析 + 设计 |

### PIVOT 触发条件

```
满足以下任一条件 → 触发 PIVOT：
  1. 连续 3 次 ITERATE 后 Spec 或 Evaluator 仍未达标
  2. spec_fit < 5（设计与实现完全对不上，可能是需求理解错了）
  3. 架构层面出现严重违规（security/correctness 核心问题）
  4. Generator 和 Evaluator 给出矛盾结论（说明 spec 本身有问题）

PIVOT 不丢人 —— 说明需求分析和设计阶段还有优化空间。
```

### PIVOT 执行流程

```
🔄 PIVOT — 方向性调整

不是简单重做上一轮的实现，而是：

1. 回到原始需求（从 harness-onboard 的 impact_analysis 开始）
2. 重新分析影响面（可能有新的相关文件/模块）
3. 重新设计方案（Planner 重新出 plan，可以复用之前的失败原因）
4. 新增一条记忆到 harness-swarm：
   {
     "type": "pivot-record",
     "reason": "之前方案在 {具体点} 上有根本性错误",
     "what-went-wrong": "...",
     "confidence": 0.3,
     "lesson": "应该先确认 {某个假设} 再开始实现"
   }
5. 重新进入 Builder → Review 循环
```

### 通过/未通过判定

| Spec Compliance | Evaluator | 行为 |
|----------------|-----------|------|
| Overall ≥ 8 | Overall ≥ 7 | ✅ 两者都通过 → **PASS** |
| Overall < 8 | — | ❌ Spec 未通过 → **ITERATE** |
| — | Overall < 7 | ❌ Evaluator 未通过 → **ITERATE** |
| MUST FIX 存在 | MUST FIX 存在 | ❌ 两者都有 MUST FIX → **ITERATE** |
| 3次 ITERATE 后仍失败 | — | 🔄 **PIVOT** |
| spec_fit < 5 | — | 🔄 **PIVOT** |

**评分处于 6-7 分区**（例如 Evaluator 6.5/10）：展示警告但不阻断，询问用户是否继续。

```
⚠️ Evaluator Overall = 6.5/10（勉强通过）

  主要扣分项：
  - readability: 5/10（变量命名不清晰，函数过长）
  - no_slop: 5/10（使用了模板生成的默认样式）

  选项：
    A. 修复这些问题
    B. 忽略，继续下一步
    C. 要求重新评分
```

---

## Step 5：GAN 迭代改进 + PIVOT 决策

当判定为 **ITERATE** 时，驱动迭代改进：

```
⏸ Review not passed. Beginning iteration {N}/3.

Generator: fix the following issues based on the scores:

  MUST FIX #1: [description]
  MUST FIX #2: [description]

  Score deductions:
  - correctness: {N}/10 ([file:line] — null pointer risk)
  - readability: {N}/10 ([file:line] — unclear variable names)

After fixing, resubmit to Evaluator for re-grading.
If Overall returns to 7+ with no MUST FIX, it passes.
```

当判定为 **PIVOT** 时，执行方向性调整（见 Step 4 PIVOT 部分）。

**Max 3 iterations. Stop and report to user after 3 failures.**

  评分扣分项：
  - correctness: 5/10（[具体代码位置] 有空指针风险）
  - readability: 5/10（[具体代码位置] 变量命名不清晰）

修复后，重新提交给 Evaluator 评分。
Evaluator 重新评分，如果 Overall 回到 7+ 且无 MUST FIX，则通过。
如果 3 次迭代后仍未通过，停止并汇报给用户裁决。
```

**迭代上限：3 次。超过后停止并报告。**

---

## Context Anxiety Handling

Watch for context anxiety signs during review:
- Model starts wrapping up at ~70% context
- Output "looks complete" but actually omits key parts

If context anxiety is suspected:
- Batch the diff processing (reduce per-session input)
- Add to prompt: "Do not wrap up early. Continue until the task is truly complete."

---

## 与 harness-dev 的衔接

- Review 通过 → 返回 harness-dev 继续下一个角色
- Review 未通过 → 进入迭代改进循环
- 3 次迭代后仍失败 → 汇报给用户：需要人工介入哪些问题
