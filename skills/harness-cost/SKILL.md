---
name: harness-cost
description: Team-level AI spend visibility. Tracks token usage per PR, attribute costs to author/reviewer, generates exportable cost reports. Built on top of harness-roles budget tracking.
---

# harness-cost：成本归因与团队可见性

> 预算管理的延伸：每个 PR 消耗多少？谁的 AI 支出最高？团队月度账单是多少？
> 目标用户：Team Lead、Engineering Manager、Finance

## 触发方式

| 方式 | 说明 |
|------|------|
| `/cost` | 查看当前分支/模块的成本汇总 |
| `/cost report` | 生成完整报告（PR 列表、月度、团队）|
| `/cost export` | 导出 CSV/JSON |
| `/cost budget` | 查看预算执行情况 |
| CI hook | PR 合并后自动记录到成本日志 |

---

## 数据来源

harness-roles 在每次 subagent 完成后输出的 token 统计：

```json
{
  "subagent": "planner",
  "model": "sonnet",
  "input_tokens": 3200,
  "output_tokens": 840,
  "cost_estimate_usd": 0.042
}
```

harness-cost 聚合这些数据，生成多维度视图。

---

## 数据存储

`.harness/cost/` 目录结构：

```
.harness/cost/
├── ledger.jsonl      # 每条记录一行（append-only）
├── summary.json      # 月度汇总缓存
└── export/           # 导出的报告
    └── 2026-04.csv
```

**ledger.jsonl 格式**：
```json
{"date":"2026-04-08","pr":"#23","author":"@zhangsan","role":"planner","model":"sonnet","input":3200,"output":840,"cost_usd":0.042,"branch":"feat/whitelist"}
{"date":"2026-04-08","pr":"#23","author":"@zhangsan","role":"builder","model":"sonnet","input":18400,"output":4200,"cost_usd":0.268,"branch":"feat/whitelist"}
```

---

## /cost 命令

### 无参数：当前分支成本

```
💰 当前分支成本 — feat/whitelist

  planner   (sonnet)     $0.042   ✗
  builder   (sonnet)     $0.268   ✓
  critic    (sonnet)     $0.089   ✓
  finalizer (haiku)      $0.012   ✓
  ─────────────────────────────
  合计                  $0.411

  平均每轮：$0.103
  当前流程：4/4 步完成
```

### /cost report：完整报告

```
💰 Forge 成本报告 — 2026-04

## 按 PR 排序

  #23 feat/whitelist          $0.41   @zhangsan
  #22 feat/user-export       $1.82   @lisi
  #21 fix/auth-bug            $0.28   @wangwu
  #20 refactor/db-layer       $3.10   @zhangsan
  ────────────────────────────────
  本月合计                   $5.61

## 按人员归因

  @zhangsan   $3.52  (63%)
  @lisi       $1.82  (32%)
  @wangwu     $0.28   (5%)

## 按角色分布

  builder     $3.10  (55%)  ← 最大支出
  planner     $1.20  (21%)
  critic      $0.89  (16%)
  finalizer   $0.42   (7%)

## vs 预算

  月预算：$50.00
  已用：   $5.61  (11%)
  剩余：   $44.39

  按此速度，预计月末：$22.40
```

### /cost export：导出

```bash
# CSV 导出
/harness-cost export --format csv --period 2026-04

# JSON 导出（方便接入 BI 工具）
/harness-cost export --format json --period 2026-04
```

---

## CI 集成：自动记录

在 GitHub Actions workflow 中追加 hook：

```yaml
# 在 harness-dev workflow 的 finalizer 步骤后追加
- name: Record cost
  run: |
    echo '{"pr":"#${{ github.event.number }}","role":"final","cost":"${{ env.COST_USD }}"}' \
      >> .harness/cost/ledger.jsonl
  env:
    COST_USD: ${{ steps.cost.outputs.total }}
```

---

## 成本估算方法

| 模型 | 输入价格 (/1M tokens) | 输出价格 (/1M tokens) |
|------|----------------------|---------------------|
| claude-opus-4-6 | $15.00 | $75.00 |
| claude-sonnet-4-6 | $3.00 | $15.00 |
| claude-haiku-4-5 | $0.80 | $4.00 |

**计算公式**：
```
cost_usd = (input_tokens / 1_000_000) * input_price
          + (output_tokens / 1_000_000) * output_price
```

---

## 预算告警

当月累计超过阈值时通知：

```
⚠️ 预算预警 — 已用 80%

  月预算：$50.00
  已用：   $40.12  (80%)
  剩余：   $9.88

  今日最后一次 PR 消耗：$0.41
  预计月末：$82.40（超出预算 $32.40）

  可选操作：
    A. 继续（不做限制）
    B. 提高预算到 $100
    C. 暂停非关键功能的 AI 辅助
```

---

## 导出格式

**CSV 格式**：
```csv
date,pr,author,role,model,input_tokens,output_tokens,cost_usd,branch
2026-04-08,#23,zhangsan,planner,sonnet,3200,840,0.042,feat/whitelist
2026-04-08,#23,zhangsan,builder,sonnet,18400,4200,0.268,feat/whitelist
```

**JSON 格式**：
```json
{
  "period": "2026-04",
  "total_cost_usd": 5.61,
  "prs": [...],
  "by_author": {...},
  "by_role": {...},
  "generated_at": "2026-04-08T12:00:00Z"
}
```

---

## 与 harness-roles 的关系

```
harness-roles 执行时
    ↓
每次 subagent 完成后输出 token 统计
    ↓
记录到 .harness/cost/ledger.jsonl
    ↓
harness-cost 读取 ledger，生成多维报告
```

harness-cost 依赖 ledger 数据，不需要修改 roles 逻辑。
