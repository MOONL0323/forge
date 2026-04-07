# Contributing to Forge

English | [中文](./CONTRIBUTING_zh-CN.md)

---

## Code of Conduct

Forge follows the [Contributor Covenant](https://www.contributor-covenant.org/).
All contributors are expected to be respectful, constructive, and collaborative.

---

## Ways to Contribute

- **Report bugs** — Use GitHub Issues with the Bug Report template
- **Suggest features** — Open a Discussion or use the Feature Request template
- **Improve docs** — PRs for README, SKILL.md, and template improvements are welcome
- **Submit skills** — New skills under `skills/` must follow the SKILL.md format
- **Code review** — Review open PRs, especially around safety and non-regression

---

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/forge.git
cd forge

# Create a test module to try your changes
mkdir -p /tmp/test-module
cd /tmp/test-module
git init

# Point to your local Forge
export FORGE_DIR=/path/to/your/forge

# Run a skill directly
# In Claude Code: /harness-init  (with your local forge skills linked)
```

---

## Skill Format

Every skill lives under `skills/<name>/SKILL.md` and must include:

```yaml
---
name: skill-name          # kebab-case, unique
description: One sentence # Shown in Claude Code /help and skill marketplace
---
```

All existing skills use **Chinese comments + English model-facing prompts**.
Keep this convention when modifying or adding skills.

---

## Pull Request Process

### 1. Branch naming

```
feat/<short-description>
fix/<issue-number>
docs/<area>
```

### 2. Before opening a PR

- [ ] `framework/version` incremented if this is a user-facing change
- [ ] `CHANGELOG.md` updated with entry under `[Unreleased]`
- [ ] New skills have frontmatter (`name`, `description`) filled in
- [ ] No breaking changes to existing skill interfaces (unless version-bumped)

### 3. PR description

Use the PR template. If no template, include:
- **What** changed and **why**
- **How to test** (if applicable)
- **Breaking changes** (if any)

### 4. Review priorities

PRs are reviewed within 1 week. Priority:
1. Security / safety regressions
2. Breaking changes without version bump
3. Documentation accuracy
4. Everything else

---

## Breaking Changes Policy

- A breaking change = any modification that changes the behavior of an existing skill interface
- Breaking changes require a minor version bump (`x.Y.z`) and must be noted in CHANGELOG.md
- `context/` files (`.harness/context/*`) are **never** overwritten by Forge upgrades — do not add breaking changes there

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
