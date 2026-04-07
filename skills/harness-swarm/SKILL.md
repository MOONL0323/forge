---
name: harness-swarm
description: Multi-agent swarm 系统，带向量记忆持久化。从历史任务中持续学习团队偏好，协调多个 Claude Code subagent 并行工作，支持语义检索已积累的经验。
---

# harness-swarm：自学习 Multi-Agent Swarm

> 借鉴 Ruflo（多 agent swarm 部署 + 自学习 + 向量记忆）和 Claude Swarm 的设计。
> 核心能力：记忆持久化 + 语义检索 + agent 协调 + 持续学习。

## 与 harness-loop 的区别

| 能力 | harness-loop | harness-swarm |
|------|-------------|---------------|
| 执行模型 | 串行 story 迭代 | 并行 agent swarm |
| 记忆 | 无 | 向量语义记忆 |
| 学习 | 无 | 从历史中持续改进 |
| 协调 | 无 | agent 间通信 |
| 适用场景 | 长时间无人值守 | 复杂多角色并行任务 |

---

## 核心概念

### 1. Semantic Memory（语义记忆）

> 简单关键词匹配 + confidence × usage_count 综合排序。
> 无外部依赖，纯本地计算。

**存储位置**：`.harness/swarm/memory/`（每条记忆一个 JSON 文件）

```json
{
  "id": "mem-001",
  "type": "pattern",
  "content": "处理 auth 接口时，先检查 session token 再访问 DB",
  "keywords": ["auth", "token", "validation", "order", "security", "session", "database"],
  "source": "harness-review@2026-04-01",
  "confidence": 0.85,
  "usage_count": 3
}
```

**检索逻辑**：
1. 从用户 query 提取关键词
2. 遍历 `.harness/swarm/memory/*.json`
3. 计算关键词命中数 × confidence × log(usage_count + 1)
4. 返回 top-5，按综合分数排序

**记忆更新规则**：
```json
{
  "if": "review PASS with usage_count >= 3 → confidence += 0.1 (上限 1.0)"
},
{
  "if": "review ITERATE → confidence -= 0.2"
},
{
  "if": "PIVOT → confidence -= 0.5，记录失败教训到 memory"
},
{
  "if": "confidence < 0.3 → 移入 archive/"
}
```

### 2. Agent Swarm（多 agent 并行）

不同于 harness-loop 的单 agent 串行，swarm 同时启动多个 agent：

```
Orchestrator（协调者）
  ├── Agent-1：代码生成
  ├── Agent-2：测试编写
  ├── Agent-3：文档更新
  └── Agent-4：Review 协调
```

每个 agent 有独立上下文，通过共享 memory 协作。

### 3. Self-Learning（自学习）

每次任务完成后，更新记忆库：
- 成功的 pattern → confidence++
- 失败的 approach → confidence-- 或删除
- 新的 solution → 新增记忆

---

## 触发方式

```
用户：「让 swarm 跑这个需求」
用户：「多 agent 并行处理这个重构」
用户：「记得上次我们怎么处理 auth 的吗」
```

---

## Step 1：加载记忆库

读取 `.harness/swarm/memory/` 下所有记忆，按相关性检索：

```
查询向量（从需求描述提取）
    ↓
与每条记忆的 embedding_hint 计算相似度
    ↓
返回 top-N 相关记忆（用于本次任务）
```

**如果没有记忆库**：初始化 `.harness/swarm/memory/` 目录。

```bash
mkdir -p .harness/swarm/memory
mkdir -p .harness/swarm/archive
```

---

## Step 2：任务分解为并行 Agent

分析需求，将任务分解为独立子任务：

```
原始需求：重构用户模块并添加测试

分解：
  Agent-1（Builder）：重构用户模块代码
  Agent-2（Tester）：为用户模块编写集成测试
  Agent-3（Reviewer）：review 重构结果
```

每个子任务派发为独立 subagent，共用：
- 相关记忆片段（embedding_hint 匹配）
- 团队 constraints.md
- 任务上下文

---

## Step 3：并行派发 Agent

**同时**派发所有 subagent，不等待一个完成再启动另一个：

```
Agent tool → Agent-1（重构）
Agent tool → Agent-2（测试）
Agent tool → Agent-3（review）
```

**共享上下文**：
- Orchestrator 维护共享 memory 路径
- 每个 agent 读取 `.harness/swarm/memory/` 中相关记忆
- 每个 agent 完成后将产出写入 `.harness/swarm/workspace/agent-N/`

---

## Step 4：收集结果 + 更新记忆

所有 agent 完成后：

```
1. 合并各 agent 产出
2. 运行 harness-review（如有代码变更）
3. 从本次任务中学习：
   - 新 pattern → 写入新记忆
   - 高频 solution → confidence++
   - 低频/失败 → confidence-- 或归档
```

**记忆更新规则**：
```json
{
  "if": "review 通过且使用次数 >= 3",
  "then": "confidence += 0.1（上限 1.0）"
}
{
  "if": "review 未通过或 3 次迭代失败",
  "then": "confidence -= 0.2，移入 archive/"
}
```

---

## Step 5：记忆检索（关键词召回）

用户可以问：
```
「上次我们怎么处理缓存失效的？」
「关于订单模块的重构有什么记忆？」
```

**检索脚本**（`.harness/swarm/retrieve.sh`）：
```bash
#!/bin/bash
# 关键词召回：命中数 × confidence × log(usage_count + 1)
QUERY="$*"
QUERY_TOKENS=$(echo "$QUERY" | tr ' ' '\n' | sort -u)

echo "查询：$QUERY"
echo "---"

for mem in .harness/swarm/memory/mem-*.json; do
  [ -f "$mem" ] || continue
  CONTENT=$(cat "$mem" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
  KEYWORDS=$(cat "$mem" | grep -o '"keywords":\[[^]]*\]' | grep -o '"[^"]*"' | tr -d '"')
  CONF=$(cat "$mem" | grep -o '"confidence":[0-9.]*' | cut -d: -f2)
  USAGE=$(cat "$mem" | grep -o '"usage_count":[0-9]*' | cut -d: -f2)

  # 计算命中数
  HITS=0
  for tok in $QUERY_TOKENS; do
    if echo "$CONTENT $KEYWORDS" | grep -qi "$tok"; then
      HITS=$((HITS + 1))
    fi
  done

  # 综合分数 = 命中数 × confidence × log(usage + 1)
  SCORE=$(echo "$HITS $CONF $USAGE" | awk '{print $1 * $2 * log($3 + 1)}')

  if [ "$HITS" -gt 0 ]; then
    echo "[$SCORE] $(basename $mem): ${CONTENT:0:80}..."
  fi
done | sort -t'[' -k2 -rn | head -5
```

**输出示例**：
```
[2.31] mem-003: 使用 Redis SETEX 处理缓存失效...
[1.58] mem-007: 缓存击穿用 singleflight...
[0.85] mem-001: 分布式锁处理并发缓存...
```

---

## 目录结构

```
.harness/swarm/
├── memory/           # 向量记忆库
│   ├── mem-001.json  # 一条记忆
│   └── mem-002.json
├── workspace/        # 各 agent 的工作目录
│   ├── agent-1/
│   ├── agent-2/
│   └── ...
├── archive/          # 低置信度记忆归档
└── state.json        # swarm 运行状态
```

---

## state.json 格式

```json
{
  "version": "1.0",
  "last_run": "2026-04-07T14:00:00Z",
  "total_runs": 12,
  "agents": ["builder", "tester", "reviewer", "documenter"],
  "memory_count": 47,
  "avg_confidence": 0.78,
  "last_patterns": [
    "auth 接口先验 token",
    "DB 操作加事务",
    "外部服务调用加 retry"
  ]
}
```

---

## 与 harness-loop 的互补

```
需要长时间无人值守（人类睡觉时）→ harness-loop
需要多角色并行 + 从历史学习   → harness-swarm
两者可以结合：loop 的 story 内可以用 swarm 并行处理
```

---

## 快速运行

```bash
# 启动 swarm
/harness-swarm

# 查看记忆库
/harness-swarm --memory

# 查询相关记忆
/harness-swarm "缓存失效"
```

---

## 依赖

- 纯 Bash + JSON，无外部依赖
- 关键词匹配 + 简单 awk 分数计算
