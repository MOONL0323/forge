#!/usr/bin/env bash
#
# Forge — One-command installer
# Usage: curl -sSL https://raw.githubusercontent.com/MOONL0323/forge/main/install.sh | bash
#

set -euo pipefail

FORGE_REPO="MOONL0323/forge"
INSTALL_DIR="${FORGE_INSTALL_DIR:-$HOME/.forge}"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

echo "🔨 Installing Forge..."
echo ""

# Check if already installed
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "📦 Forge already installed at $INSTALL_DIR"
  echo "   Run 'git -C $INSTALL_DIR pull' to update"
else
  echo "📥 Cloning Forge..."
  git clone --depth 1 https://github.com/$FORGE_REPO.git "$INSTALL_DIR"
fi

# Copy skills to Claude Code
if [ -d "$CLAUDE_SKILLS_DIR" ]; then
  cp -r "$INSTALL_DIR/skills/"* "$CLAUDE_SKILLS_DIR/"
  echo "✅ Skills copied to $CLAUDE_SKILLS_DIR"
else
  echo "⚠️  Claude Code skills directory not found at $CLAUDE_SKILLS_DIR"
  echo "   Please install Claude Code first: https://claude.ai/code"
fi

# Copy templates
TEMPLATE_DIR="$INSTALL_DIR/templates"
if [ -d "$TEMPLATE_DIR" ]; then
  echo "✅ Templates available at $TEMPLATE_DIR"
fi

echo ""
echo "✅ Forge installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Install Superpowers (recommended):"
echo "     /plugin install superpowers@superpowers-marketplace"
echo ""
echo "  2. Initialize a module:"
echo "     cd your-monorepo/cmd/my-service"
echo "     /harness-init"
echo ""
echo "  3. Describe what you want to build:"
echo "     你：帮我给白名单功能加个产线维度"
echo ""
echo "Docs: https://github.com/$FORGE_REPO"
