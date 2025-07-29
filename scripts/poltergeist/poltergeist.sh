#!/bin/bash
# Poltergeist - The Universal Swift Build Watcher
# A ghost that watches your Swift files and rebuilds when they change

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/poltergeist.config.json"
LOCK_FILE="/tmp/peekaboo-poltergeist.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Ghost emoji for fun
GHOST="👻"

function print_status() {
    echo -e "${GREEN}${GHOST} [Poltergeist]${NC} $1"
}

function print_error() {
    echo -e "${RED}${GHOST} [Poltergeist]${NC} $1" >&2
}

function print_warning() {
    echo -e "${YELLOW}${GHOST} [Poltergeist]${NC} $1"
}

function print_info() {
    echo -e "${CYAN}${GHOST} [Poltergeist]${NC} $1"
}

function check_dependencies() {
    if ! command -v watchman &> /dev/null; then
        print_error "Watchman not found!"
        echo -e "${PURPLE}Install with:${NC} brew install watchman"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq not found!"
        echo -e "${PURPLE}Install with:${NC} brew install jq"
        exit 1
    fi
}

function parse_mode() {
    local mode="all"
    
    for arg in "$@"; do
        case $arg in
            --cli)
                mode="cli"
                ;;
            --mac)
                mode="mac"
                ;;
            --all)
                mode="all"
                ;;
        esac
    done
    
    echo "$mode"
}

function is_enabled() {
    local target=$1
    if [ ! -f "$CONFIG_FILE" ]; then
        # Default behavior if no config exists
        [[ "$target" == "cli" ]] && echo "true" || echo "false"
        return
    fi
    
    jq -r ".${target}.enabled // false" "$CONFIG_FILE" 2>/dev/null || echo "false"
}

function start_watcher() {
    check_dependencies
    
    local mode=$(parse_mode "$@")
    local cli_enabled=$(is_enabled "cli")
    local mac_enabled=$(is_enabled "macApp")
    
    # Override based on mode
    case $mode in
        cli)
            mac_enabled="false"
            ;;
        mac)
            cli_enabled="false"
            ;;
    esac
    
    # Check if already running
    if watchman watch-list 2>/dev/null | grep -q "$PROJECT_ROOT"; then
        print_warning "Poltergeist is already haunting this project!"
        print_info "Use 'poltergeist rest' to stop it first"
        return 0
    fi
    
    print_status "Summoning Poltergeist to watch your Swift files..."
    
    # Watch the project
    watchman watch-project "$PROJECT_ROOT" >/dev/null 2>&1
    
    # Create triggers based on what's enabled
    if [[ "$cli_enabled" == "true" ]]; then
        create_cli_trigger
    fi
    
    if [[ "$mac_enabled" == "true" ]]; then
        create_mac_trigger
    fi
    
    # Create lock file
    echo $$ > "$LOCK_FILE"
    
    print_status "Poltergeist is now haunting your Swift files!"
    
    if [[ "$cli_enabled" == "true" ]] && [[ "$mac_enabled" == "true" ]]; then
        print_info "Watching both CLI and Mac app"
    elif [[ "$cli_enabled" == "true" ]]; then
        print_info "Watching CLI only"
    elif [[ "$mac_enabled" == "true" ]]; then
        print_info "Watching Mac app only"
    fi
    
    echo -e "${PURPLE}Commands:${NC}"
    echo "  poltergeist status  - Check if the ghost is active"
    echo "  poltergeist rest    - Send the ghost to rest"
    echo "  poltergeist logs    - See what the ghost has been up to"
}

function create_cli_trigger() {
    print_info "Setting up CLI file watcher..."
    
    watchman -j <<-EOF
    ["trigger", "$PROJECT_ROOT", {
        "name": "poltergeist-cli-rebuild",
        "expression": ["allof",
            ["anyof",
                ["match", "Core/PeekabooCore/**/*.swift", "wholename"],
                ["match", "Core/AXorcist/**/*.swift", "wholename"],
                ["match", "Apps/CLI/**/*.swift", "wholename"],
                ["match", "**/Package.swift", "wholename"],
                ["match", "**/Package.resolved", "wholename"]
            ],
            ["not", ["match", "**/Version.swift", "wholename"]]
        ],
        "command": ["$PROJECT_ROOT/scripts/poltergeist/poltergeist-handler.sh", "cli"],
        "append_files": false,
        "stdin": ["name", "exists", "new", "size", "mode"],
        "settling_delay": 1000
    }]
EOF
}

function create_mac_trigger() {
    print_info "Setting up Mac app file watcher..."
    
    watchman -j <<-EOF
    ["trigger", "$PROJECT_ROOT", {
        "name": "poltergeist-mac-rebuild",
        "expression": ["allof",
            ["anyof",
                ["match", "Apps/Mac/Peekaboo/**/*.swift", "wholename"],
                ["match", "Apps/Mac/Peekaboo/**/*.storyboard", "wholename"],
                ["match", "Apps/Mac/Peekaboo/**/*.xib", "wholename"],
                ["match", "Core/PeekabooCore/**/*.swift", "wholename"],
                ["match", "Core/AXorcist/**/*.swift", "wholename"],
                ["match", "**/Package.swift", "wholename"]
            ],
            ["not", ["match", "**/Version.swift", "wholename"]]
        ],
        "command": ["$PROJECT_ROOT/scripts/poltergeist/poltergeist-handler.sh", "mac"],
        "append_files": false,
        "stdin": ["name", "exists", "new", "size", "mode"],
        "settling_delay": 1500
    }]
EOF
}

function stop_watcher() {
    check_dependencies
    
    print_status "Sending Poltergeist to rest..."
    
    # Remove triggers
    watchman trigger-del "$PROJECT_ROOT" "poltergeist-cli-rebuild" 2>/dev/null || true
    watchman trigger-del "$PROJECT_ROOT" "poltergeist-mac-rebuild" 2>/dev/null || true
    
    # Remove the watch
    watchman watch-del "$PROJECT_ROOT" 2>/dev/null || true
    
    # Remove lock file
    rm -f "$LOCK_FILE"
    
    print_status "Poltergeist is now at rest 💤"
}

function show_status() {
    check_dependencies
    
    echo -e "\n${PURPLE}=== Poltergeist Status ===${NC}"
    
    # Check if watch exists
    if watchman watch-list 2>/dev/null | grep -q "$PROJECT_ROOT"; then
        echo -e "${GREEN}✓${NC} Project watch: ${GREEN}ACTIVE${NC}"
        
        # Check CLI trigger
        if watchman trigger-list "$PROJECT_ROOT" 2>/dev/null | grep -q "poltergeist-cli-rebuild"; then
            echo -e "${GREEN}✓${NC} CLI rebuild trigger: ${GREEN}HAUNTING${NC}"
            
            # Show CLI build status
            if [ -f "/tmp/peekaboo-cli-build-status.json" ]; then
                local cli_status=$(jq -r '.status' "/tmp/peekaboo-cli-build-status.json" 2>/dev/null || echo "unknown")
                local cli_time=$(jq -r '.timestamp' "/tmp/peekaboo-cli-build-status.json" 2>/dev/null || echo "never")
                echo -e "   └─ Last build: $cli_status at $cli_time"
            fi
        else
            echo -e "${RED}✗${NC} CLI rebuild trigger: ${RED}NOT ACTIVE${NC}"
        fi
        
        # Check Mac trigger  
        if watchman trigger-list "$PROJECT_ROOT" 2>/dev/null | grep -q "poltergeist-mac-rebuild"; then
            echo -e "${GREEN}✓${NC} Mac app rebuild trigger: ${GREEN}HAUNTING${NC}"
            
            # Show Mac build status
            if [ -f "/tmp/peekaboo-mac-build-status.json" ]; then
                local mac_status=$(jq -r '.status' "/tmp/peekaboo-mac-build-status.json" 2>/dev/null || echo "unknown")
                local mac_time=$(jq -r '.timestamp' "/tmp/peekaboo-mac-build-status.json" 2>/dev/null || echo "never")
                echo -e "   └─ Last build: $mac_status at $mac_time"
            fi
        else
            echo -e "${RED}✗${NC} Mac app rebuild trigger: ${RED}NOT ACTIVE${NC}"
        fi
    else
        echo -e "${RED}✗${NC} Project watch: ${YELLOW}DORMANT${NC}"
    fi
    
    # Show recent activity
    echo -e "\n${PURPLE}=== Recent Poltergeist Activity ===${NC}"
    if [ -f "$PROJECT_ROOT/.poltergeist.log" ]; then
        tail -n 10 "$PROJECT_ROOT/.poltergeist.log"
    else
        echo "No activity detected yet"
    fi
}

function show_logs() {
    if [ -f "$PROJECT_ROOT/.poltergeist.log" ]; then
        print_info "Showing Poltergeist activity (Ctrl+C to exit)..."
        tail -f "$PROJECT_ROOT/.poltergeist.log"
    else
        print_error "No activity log found - Poltergeist hasn't done anything yet"
        exit 1
    fi
}

function show_help() {
    cat << EOF

${PURPLE}${GHOST} Poltergeist - The Universal Swift Build Watcher${NC}

A helpful ghost that watches your Swift files and rebuilds your projects when they change.

${CYAN}Usage:${NC} poltergeist [command] [options]

${CYAN}Commands:${NC}
  ${GREEN}start${NC}     Summon the Poltergeist to watch Swift files
  ${GREEN}haunt${NC}     Same as start (more thematic!)
  ${GREEN}stop${NC}      Send the Poltergeist to rest  
  ${GREEN}rest${NC}      Same as stop (more thematic!)
  ${GREEN}status${NC}    Check if Poltergeist is active
  ${GREEN}logs${NC}      See what Poltergeist has been up to
  ${GREEN}help${NC}      Show this help message

${CYAN}Options:${NC}
  ${GREEN}--cli${NC}     Watch only CLI files
  ${GREEN}--mac${NC}     Watch only Mac app files  
  ${GREEN}--all${NC}     Watch both CLI and Mac app (default)

${CYAN}What it does:${NC}
Poltergeist watches your Swift files and automatically rebuilds:
  • CLI tool when CLI sources change
  • Mac app when Mac app sources change
  • Both share Core libraries (PeekabooCore, AXorcist)

The Mac app builder can automatically quit and relaunch the app after successful builds.

${CYAN}Examples:${NC}
  poltergeist haunt         # Watch everything
  poltergeist haunt --cli   # Watch only CLI files
  poltergeist haunt --mac   # Watch only Mac app files
  poltergeist status        # Check what's being watched
  poltergeist rest          # Stop watching

${CYAN}Configuration:${NC}
Edit ${PURPLE}poltergeist.config.json${NC} to customize build commands, paths, and auto-relaunch settings.

EOF
}

# Main command handling
case "${1:-help}" in
    start|haunt)
        start_watcher "$@"
        ;;
    stop|rest)
        stop_watcher
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac