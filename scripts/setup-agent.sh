#!/bin/bash
# YDAPI Agent Setup Script
# Run this on your machine to configure Claude Code / Codex / Cursor to use YDAPI
#
# Usage: bash setup-agent.sh <platform> <api_key>
# Platforms: claude, openai, gemini
#
# Example:
#   bash setup-agent.sh claude sk-xxxxx

set -e

YDAPI_URL="${YDAPI_URL:?Set YDAPI_URL (e.g. https://your-server)}"
PLATFORM="${1:-}"
API_KEY="${2:-}"

if [ -z "$PLATFORM" ] || [ -z "$API_KEY" ]; then
  echo "YDAPI Agent Setup"
  echo ""
  echo "Usage: $0 <platform> <api_key>"
  echo ""
  echo "Platforms:"
  echo "  claude  - Claude Code / Anthropic API"
  echo "  openai  - Codex CLI / OpenAI API"
  echo "  gemini  - Gemini API"
  echo ""
  echo "Get your API key from: $YDAPI_URL"
  exit 1
fi

echo "Setting up YDAPI for $PLATFORM..."

case "$PLATFORM" in
  claude)
    # Claude Code
    export ANTHROPIC_BASE_URL="$YDAPI_URL"
    export ANTHROPIC_API_KEY="$API_KEY"

    # Persist to shell profile
    PROFILE="${ZDOTDIR:-$HOME}/.zshrc"
    [ -f "$HOME/.bashrc" ] && [ ! -f "$PROFILE" ] && PROFILE="$HOME/.bashrc"

    grep -q "ANTHROPIC_BASE_URL" "$PROFILE" 2>/dev/null && \
      sed -i.bak "/ANTHROPIC_BASE_URL/d;/ANTHROPIC_API_KEY/d" "$PROFILE"

    echo "" >> "$PROFILE"
    echo "# YDAPI Claude Config" >> "$PROFILE"
    echo "export ANTHROPIC_BASE_URL=\"$YDAPI_URL\"" >> "$PROFILE"
    echo "export ANTHROPIC_API_KEY=\"$API_KEY\"" >> "$PROFILE"

    echo "Claude Code configured!"
    echo "  ANTHROPIC_BASE_URL=$YDAPI_URL"
    echo "  ANTHROPIC_API_KEY=${API_KEY:0:20}..."
    echo ""
    echo "Run: source $PROFILE"
    ;;

  openai)
    # Codex CLI / OpenAI
    export OPENAI_BASE_URL="$YDAPI_URL/openai"
    export OPENAI_API_KEY="$API_KEY"

    PROFILE="${ZDOTDIR:-$HOME}/.zshrc"
    [ -f "$HOME/.bashrc" ] && [ ! -f "$PROFILE" ] && PROFILE="$HOME/.bashrc"

    grep -q "OPENAI_BASE_URL" "$PROFILE" 2>/dev/null && \
      sed -i.bak "/OPENAI_BASE_URL/d;/OPENAI_API_KEY/d" "$PROFILE"

    echo "" >> "$PROFILE"
    echo "# YDAPI OpenAI Config" >> "$PROFILE"
    echo "export OPENAI_BASE_URL=\"$YDAPI_URL/openai\"" >> "$PROFILE"
    echo "export OPENAI_API_KEY=\"$API_KEY\"" >> "$PROFILE"

    echo "OpenAI/Codex configured!"
    echo "  OPENAI_BASE_URL=$YDAPI_URL/openai"
    echo "  OPENAI_API_KEY=${API_KEY:0:20}..."
    echo ""
    echo "Run: source $PROFILE"
    ;;

  gemini)
    export GEMINI_API_BASE="$YDAPI_URL/gemini"
    export GEMINI_API_KEY="$API_KEY"

    PROFILE="${ZDOTDIR:-$HOME}/.zshrc"
    [ -f "$HOME/.bashrc" ] && [ ! -f "$PROFILE" ] && PROFILE="$HOME/.bashrc"

    grep -q "GEMINI_API_BASE" "$PROFILE" 2>/dev/null && \
      sed -i.bak "/GEMINI_API_BASE/d;/GEMINI_API_KEY/d" "$PROFILE"

    echo "" >> "$PROFILE"
    echo "# YDAPI Gemini Config" >> "$PROFILE"
    echo "export GEMINI_API_BASE=\"$YDAPI_URL/gemini\"" >> "$PROFILE"
    echo "export GEMINI_API_KEY=\"$API_KEY\"" >> "$PROFILE"

    echo "Gemini configured!"
    echo "  GEMINI_API_BASE=$YDAPI_URL/gemini"
    echo "  GEMINI_API_KEY=${API_KEY:0:20}..."
    echo ""
    echo "Run: source $PROFILE"
    ;;

  *)
    echo "Unknown platform: $PLATFORM"
    echo "Supported: claude, openai, gemini"
    exit 1
    ;;
esac

# Test connection
echo ""
echo "Testing connection..."
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "$YDAPI_URL/health")
if [ "$HTTP_CODE" = "200" ]; then
  echo "YDAPI is reachable. Ready to go!"
else
  echo "WARNING: YDAPI returned HTTP $HTTP_CODE. Check your network."
fi
