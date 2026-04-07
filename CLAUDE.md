# Forge Contributor Guide

This is the Forge framework itself — an AI-driven development workflow for Claude Code.

## Working on Forge

When working in this repo, you are a **Forge developer**, not a harness user.

### Skill development

- Skills are under `skills/<name>/SKILL.md`
- Follow the frontmatter format: `name`, `description`
- Model-facing prompts → English. Comments/internal docs → Chinese.
- After modifying a skill, update `framework/version` (patch bump for fixes, minor for new features)
- Add entry to `CHANGELOG.md` under `[Unreleased]`

### Template development

- Module templates: `templates/module/`
- Pkg templates: `templates/pkg/`
- Template files ending in `.tmpl` are consumed by `harness-init`
- Never add breaking changes to `context/` template files — these persist in user modules

### Testing your changes

```bash
# 1. Create a test module
mkdir -p /tmp/forge-test && cd /tmp/forge-test
git init

# 2. In Claude Code, run harness-init from your local fork:
#    (link skills from this repo via ~/.claude/skills/ then)
/harness-init

# 3. Try a development scenario
#    你：帮我加一个 ping 功能

# 4. Verify output is sensible
```

### Version bumping

```
framework/version format: MAJOR.MINOR.PATCH (e.g. 1.0.1)
Patch: bug fixes
Minor: new features (non-breaking)
Major: breaking changes
```

---

## Relevant Patterns

- **Anthropic Generator/Evaluator**: harness-review uses this
- **Ralph Wiggum Loop**: harness-loop implements fresh-context iteration
- **OpenAI Harness Engineering**: constraints.md → mechanical enforcement
- **Anti-leniency scoring**: Evaluator must cite specific `{file}:{line}` for low scores
- **Superpowers integration**: skills reference `superpowers:xxx` with `fallback: xxx`
