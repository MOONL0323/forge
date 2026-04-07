# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability within Forge, please follow responsible disclosure:

**Do NOT** create a public GitHub Issue for security vulnerabilities.

**Instead:**
1. Email the maintainer directly at the GitHub profile URL
2. Include a detailed description of the vulnerability
3. If possible, include a minimal reproduction case

We aim to respond within 48 hours and will work with you to:
- Confirm the vulnerability
- Provide a timeline for a fix
- Credit you in the security advisory (if you wish)

## Security Best Practices for Users

When using Forge in your project:

- **Never commit `.harness/context/`** files containing secrets to version control
- **Review `constraints.md`** before enabling auto-enforcement hooks
- **`allowedTools`** in subagent dispatch are security boundaries — do not remove them
- **CI Auto-Fix** runs with `contents: write` permission only; it cannot access secrets
- **API keys** for GitHub Actions (`GITHUB_TOKEN`) are provided by GitHub automatically and scoped to the repository

## Scope

Forge itself is a workflow framework that runs within Claude Code. It does not:
- Access external networks except via user-initiated commands
- Store credentials beyond local `.harness/` files
- Execute arbitrary code from untrusted sources
