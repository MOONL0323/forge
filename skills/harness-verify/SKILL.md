---
name: harness-verify
description: 动态设计验证。通过 Playwright 在真实浏览器中运行并截图，测试响应式视口、WCAG 可访问性、Console 错误。替换纯静态 diff 分析，用视觉证据说话。
---

# harness-verify：Live Environment Design Verification

> Anthropic Quickstart 的核心方法论：**"Live Environment First"**
> 在静态分析之前先用 Playwright 验证运行环境。
> 7-Phase Design Review：Interaction / Responsiveness / Visual / A11y / Robustness / Code / Console

## 触发方式

```
用户：「验证这个 UI 变更」
用户：「在浏览器里看看这个页面」
用户：「截图看看效果」
用户：「检查一下响应式布局」
```

**自动触发**：当 `harness-review` 的评分处于 6-7 分区且涉及 UI 变更时，建议调用。

---

## Step 1：判断是否需要 live 验证

```
以下情况必须 live 验证：
  - 涉及 HTML/CSS/JS 前端变更
  - 涉及 UI 组件库变更
  - 涉及页面布局、样式、响应式
  - 涉及用户交互行为

以下情况可跳过：
  - 纯后端 API 变更
  - 配置文件变更
  - 文档变更
  - 测试文件变更
```

如果跳过，输出：`SKIP — 无 UI 变更，无需 live 验证`

---

## Step 2：检查 Playwright 环境

```bash
# 检查 playwright 是否可用
if ! command -v playwright &> /dev/null; then
  echo "⚠️  Playwright 未安装"
  echo "Install: npm install -g playwright && playwright install chromium"
  echo "Or use npx: npx playwright --version"
fi

# 检查是否有可用的 browser
playwright --version 2>/dev/null || npx playwright --version 2>/dev/null || echo "NO_PLAYWRIGHT"
```

**降级处理**：
- Playwright 不可用 → 使用 curl 截图服务（如 shot.screenshot API）作为 fallback
- 如果截图服务也不可用 → 输出 `⚠️ 无法 live 验证，降级为静态分析`

---

## Step 3：生成 Playwright 验证脚本

为每个变更的 UI 文件生成验证脚本：

```javascript
// .harness/verify/temp-verify-{timestamp}.js
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 }
  });

  const page = await context.newPage();

  // 1. 加载页面
  await page.goto('file:///path/to/changed/file.html', { waitUntil: 'networkidle' });

  // 2. 捕获 Console 错误
  const consoleErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });

  // 3. 截图
  await page.screenshot({ path: '.harness/verify/screenshots/desktop-{timestamp}.png', fullPage: false });
  await page.screenshot({ path: '.harness/verify/screenshots/desktop-full-{timestamp}.png', fullPage: true });

  // 4. 响应式测试（视口）
  const viewports = [
    { name: 'mobile', width: 375, height: 812 },
    { name: 'tablet', width: 768, height: 1024 },
    { name: 'laptop', width: 1440, height: 900 }
  ];

  for (const vp of viewports) {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    await page.screenshot({
      path: `.harness/verify/screenshots/${vp.name}-{timestamp}.png`,
      fullPage: false
    });
  }

  // 5. 交互测试（如果有按钮、表单）
  const buttons = await page.$$('button');
  for (const btn of buttons) {
    await btn.hover();
    await btn.click({ force: true });
    await page.waitForTimeout(300);
  }

  // 6. Console 错误
  if (consoleErrors.length > 0) {
    console.log('CONSOLE_ERRORS:');
    consoleErrors.forEach(e => console.log('  - ' + e));
  }

  await browser.close();
  console.log('VERIFY_DONE');
})();
```

---

## Step 4：执行验证

```bash
# 创建截图目录
mkdir -p .harness/verify/screenshots

# 运行 Playwright 脚本
node .harness/verify/temp-verify-{timestamp}.js

# 如果涉及 API 后端，先启动本地服务
# (cd app && npm run dev) &
# sleep 5
# node .harness/verify/temp-verify-{timestamp}.js
```

---

## Step 5：7-Phase Design Review

对每次截图执行 7 维度检查：

```
## Phase 1: Interaction（交互）
  - 按钮可点击？有 hover 效果？
  - 表单可提交？有验证提示？
  - 导航流畅？有 active 状态？

## Phase 2: Responsiveness（响应式）
  - mobile (375px): 内容是否溢出？字体是否可读？
  - tablet (768px): 布局是否自适应？
  - laptop (1440px): 是否有空白浪费？

## Phase 3: Visual（视觉）
  - 颜色是否符合品牌规范？
  - 间距是否一致？
  - 是否有明显的布局错位？

## Phase 4: Accessibility（WCAG AA）
  - 文字对比度是否 ≥ 4.5:1？
  - 是否有 alt 文本（图片）？
  - 键盘可导航？（Tab 顺序）
  - 焦点可见？

## Phase 5: Robustness（健壮性）
  - 网络差时是否有 loading 状态？
  - 错误时是否有友好提示？
  - 空白状态是否有占位？

## Phase 6: Code（代码）
  - DOM 结构语义化？（header/main/footer/nav）
  - 无内联样式？（样式分离）
  - 无资源 404？（检查网络请求）

## Phase 7: Console（控制台）
  - 是否有 JS 错误？（ERROR 级别）
  - 是否有未捕获的异常？
  - 是否有 CORS 错误？
```

---

## Step 6：Triage 矩阵

```
┌─────────────────────────────────────────────────────┐
│  Live Verification Results                           │
├─────────────────────────────────────────────────────┤
│  BLOCKER（必须修复）                                   │
│  🛑 Console ERROR: [具体错误] @ [文件:行号]           │
│  🛑 移动端布局完全崩溃（内容溢出、元素重叠）             │
│  🛑 关键交互无响应（按钮点击无效）                      │
│                                                      │
│  HIGH（强烈建议修复）                                  │
│  ⚠️  文字对比度 3.2:1（低于 WCAG AA 4.5:1）          │
│  ⚠️  移动端字体 < 14px，可读性差                        │
│  ⚠️  图片缺少 alt 属性                                │
│                                                      │
│  MEDIUM（可以接受但需改进）                             │
│  🔶  间距不一致（16px vs 24px）                       │
│  🔶  loading 状态样式简陋                              │
│                                                      │
│  NITPICK（吹毛求疵）                                  │
│  💬  按钮颜色可以更鲜明一些                             │
└─────────────────────────────────────────────────────┘
```

---

## Step 7：与 harness-review 整合

```
harness-review 评分处于 6-7 区间时：
  ↓
自动调用 harness-verify
  ↓
Playwright 执行 + 截图
  ↓
生成 Triage 矩阵 + 截图证据
  ↓
返回给 harness-review 更新评分
  ↓
如果 3 次迭代后仍 FAIL，汇报给用户时附带截图证据
```

---

## 快速运行

```bash
# 完整验证
/harness-verify

# 快速截图（不运行交互测试）
/harness-verify --screenshot-only

# 指定文件
/harness-verify "src/components/LoginForm.tsx"
```

---

## 依赖

- `playwright`（可选，`npx playwright` fallback）
- 无 Playwright 时降级为截图服务 API 或静态分析
