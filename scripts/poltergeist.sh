#!/bin/bash
# Poltergeist - The Swift CLI File Watcher
# A ghost that watches your Swift files and rebuilds when they change

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TRIGGER_NAME="poltergeist-swift-rebuild"
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

function check_watchman() {
    if ! command -v watchman &> /dev/null; then
        print_error "Watchman not found!"
        echo -e "${PURPLE}Install with:${NC} brew install watchman"
        exit 1
    fi
}

function start_watcher() {
    check_watchman
    
    # Check if already running
    if watchman watch-list 2>/dev/null | grep -q "$PROJECT_ROOT"; then
        print_warning "Poltergeist is already haunting this project!"
        return 0
    fi
    
    print_status "Summoning Poltergeist to watch your Swift files..."
    
    # Watch the project
    watchman watch-project "$PROJECT_ROOT" >/dev/null 2>&1
    
    # Create trigger for Swift files
    watchman -j <<-EOF
    ["trigger", "$PROJECT_ROOT", {
        "name": "$TRIGGER_NAME",
        "expression": ["anyof",
            ["match", "Core/PeekabooCore/**/*.swift", "wholename"],
            ["match", "Core/AXorcist/**/*.swift", "wholename"],
            ["match", "Apps/CLI/**/*.swift", "wholename"],
            ["match", "**/Package.swift", "wholename"],
            ["match", "**/Package.resolved", "wholename"]
        ],
        "command": ["$PROJECT_ROOT/scripts/poltergeist-handler.sh"],
        "append_files": false,
        "stdin": ["name", "exists", "new", "size", "mode"]
    }]
EOF
    
    if [ $? -eq 0 ]; then
        print_status "Poltergeist is now haunting your Swift files!"
        print_info "Watching: Core/PeekabooCore, Core/AXorcist, Apps/CLI"
        echo -e "${PURPLE}Commands:${NC}"
        echo "  poltergeist status - Check if the ghost is active"
        echo "  poltergeist rest   - Send the ghost to rest"
        echo "  poltergeist logs   - See what the ghost has been up to"
        
        # Create lock file
        echo $$ > "$LOCK_FILE"
    else
        print_error "Failed to summon Poltergeist!"
        exit 1
    fi
}

function stop_watcher() {
    check_watchman
    
    print_status "Sending Poltergeist to rest..."
    
    # Remove trigger first
    if watchman trigger-del "$PROJECT_ROOT" "$TRIGGER_NAME" 2>/dev/null; then
        print_info "Trigger removed successfully"
    else
        print_warning "No trigger found to remove"
    fi
    
    # Remove the watch entirely to ensure clean state
    if watchman watch-del "$PROJECT_ROOT" 2>/dev/null; then
        print_info "Watch removed successfully"
    else
        print_warning "No watch found to remove"
    fi
    
    # Remove lock file
    rm -f "$LOCK_FILE"
    
    print_status "Poltergeist is now at rest 💤"
}

function show_status() {
    check_watchman
    
    echo -e "\n${PURPLE}=== Poltergeist Status ===${NC}"
    
    # Check if watch exists
    if watchman watch-list 2>/dev/null | grep -q "$PROJECT_ROOT"; then
        echo -e "${GREEN}✓${NC} Project watch: ${GREEN}ACTIVE${NC}"
        
        # Check if trigger exists
        if watchman trigger-list "$PROJECT_ROOT" 2>/dev/null | grep -q "$TRIGGER_NAME"; then
            echo -e "${GREEN}✓${NC} Swift rebuild trigger: ${GREEN}HAUNTING${NC}"
            echo ""
            echo "Watching for changes in:"
            echo "  • Core/PeekabooCore/**/*.swift"
            echo "  • Core/AXorcist/**/*.swift"
            echo "  • Apps/CLI/**/*.swift"
            echo "  • **/Package.swift"
            echo "  • **/Package.resolved"
        else
            echo -e "${RED}✗${NC} Swift rebuild trigger: ${RED}NOT FOUND${NC}"
        fi
    else
        echo -e "${RED}✗${NC} Project watch: ${YELLOW}DORMANT${NC}"
    fi
    
    # Show recent trigger activity
    echo -e "\n${PURPLE}=== Recent Poltergeist Activity ===${NC}"
    if [ -f "$PROJECT_ROOT/.poltergeist.log" ]; then
        tail -n 5 "$PROJECT_ROOT/.poltergeist.log"
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

${PURPLE}${GHOST} Poltergeist - The Swift CLI File Watcher${NC}

A helpful ghost that watches your Swift files and rebuilds the CLI when they change.

${CYAN}Usage:${NC} poltergeist [command]

${CYAN}Commands:${NC}
  ${GREEN}start${NC}     Summon the Poltergeist to watch Swift files
  ${GREEN}haunt${NC}     Same as start (more thematic!)
  ${GREEN}stop${NC}      Send the Poltergeist to rest  
  ${GREEN}rest${NC}      Same as stop (more thematic!)
  ${GREEN}status${NC}    Check if Poltergeist is active
  ${GREEN}logs${NC}      See what Poltergeist has been up to
  ${GREEN}help${NC}      Show this help message

${CYAN}What it does:${NC}
When active, Poltergeist watches for changes in:
  • Core/PeekabooCore
  • Core/AXorcist  
  • Apps/CLI
  • Package files

And automatically rebuilds the Swift CLI when changes are detected.

${CYAN}Example:${NC}
  poltergeist haunt    # Start watching
  poltergeist status   # Check if it's running
  poltergeist rest     # Stop watching

EOF
}

# Main command handling
case "${1:-help}" in
    start|haunt)
        start_watcher
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