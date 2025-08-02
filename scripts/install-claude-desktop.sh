#!/bin/bash
# install-claude-desktop.sh - Install Peekaboo MCP in Claude Desktop

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BINARY_PATH="$PROJECT_ROOT/peekaboo"
CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

echo -e "${BLUE}🔧 Peekaboo MCP Installer for Claude Desktop${NC}"
echo

# Check if Claude Desktop is installed
if [ ! -d "$CONFIG_DIR" ]; then
    echo -e "${RED}❌ Claude Desktop not found!${NC}"
    echo "Please install Claude Desktop from: https://claude.ai/download"
    exit 1
fi

# Check if Peekaboo binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo -e "${YELLOW}⚠️  Peekaboo binary not found. Building...${NC}"
    cd "$PROJECT_ROOT"
    npm run build:swift
    
    if [ ! -f "$BINARY_PATH" ]; then
        echo -e "${RED}❌ Build failed!${NC}"
        exit 1
    fi
fi

# Make binary executable
chmod +x "$BINARY_PATH"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Backup existing config if it exists
if [ -f "$CONFIG_FILE" ]; then
    BACKUP_FILE="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}📋 Backing up existing config to: $BACKUP_FILE${NC}"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
fi

# Function to merge JSON configs
merge_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # Use Python to merge configs
        python3 -c "
import json
import sys

# Read existing config
try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)
except:
    config = {}

# Ensure mcpServers exists
if 'mcpServers' not in config:
    config['mcpServers'] = {}

# Add or update Peekaboo
config['mcpServers']['peekaboo'] = {
    'command': '$BINARY_PATH',
    'args': ['mcp', 'serve'],
    'env': {
        'PEEKABOO_LOG_LEVEL': 'info'
    }
}

# Write back
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
"
    else
        # Create new config
        cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "peekaboo": {
      "command": "$BINARY_PATH",
      "args": ["mcp", "serve"],
      "env": {
        "PEEKABOO_LOG_LEVEL": "info"
      }
    }
  }
}
EOF
    fi
}

# Install the configuration
echo -e "${BLUE}📝 Updating Claude Desktop configuration...${NC}"
merge_config

# Check for API keys
echo
echo -e "${BLUE}🔑 Checking API keys...${NC}"

check_api_key() {
    local key_name=$1
    local env_var=$2
    
    if [ -z "${!env_var}" ]; then
        if [ -f "$HOME/.peekaboo/credentials" ] && grep -q "^$env_var=" "$HOME/.peekaboo/credentials"; then
            echo -e "${GREEN}✓ $key_name found in ~/.peekaboo/credentials${NC}"
        else
            echo -e "${YELLOW}⚠️  $key_name not configured${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ $key_name found in environment${NC}"
    fi
    return 0
}

MISSING_KEYS=false
check_api_key "Anthropic API key" "ANTHROPIC_API_KEY" || MISSING_KEYS=true
check_api_key "OpenAI API key" "OPENAI_API_KEY" || true  # Optional
check_api_key "xAI API key" "X_AI_API_KEY" || true  # Optional

if [ "$MISSING_KEYS" = true ]; then
    echo
    echo -e "${YELLOW}To configure API keys, run:${NC}"
    echo "  $BINARY_PATH config set-credential ANTHROPIC_API_KEY sk-ant-..."
fi

# Check permissions
echo
echo -e "${BLUE}🔒 Checking system permissions...${NC}"

check_permission() {
    local service=$1
    local display_name=$2
    
    # This is a simplified check - actual permission checking is complex
    echo -e "${YELLOW}⚠️  Please ensure $display_name permission is granted${NC}"
    echo "   System Settings → Privacy & Security → $display_name"
}

check_permission "com.apple.accessibility" "Accessibility"
check_permission "com.apple.screencapture" "Screen Recording"

# Success message
echo
echo -e "${GREEN}✅ Peekaboo MCP installed successfully!${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Restart Claude Desktop"
echo "2. Start a new conversation"
echo "3. Try: 'Can you take a screenshot of my desktop?'"
echo
echo -e "${BLUE}Troubleshooting:${NC}"
echo "- Check logs: tail -f ~/Library/Logs/Claude/mcp*.log"
echo "- Monitor Peekaboo: $PROJECT_ROOT/scripts/pblog.sh -f"
echo "- Test manually: $BINARY_PATH mcp serve"
echo
echo -e "${BLUE}Configuration file:${NC} $CONFIG_FILE"