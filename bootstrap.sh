#!/bin/bash

# Deploy-Kit Bootstrap Script
# Quick setup script for Deploy-Kit deployment toolkit
# This script provides a fast way to get Deploy-Kit up and running

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${timestamp} [${level}] ${message}"
    
    case $level in
        "ERROR") echo -e "${RED}${message}${NC}" ;;
        "WARN")  echo -e "${YELLOW}${message}${NC}" ;;
        "INFO")  echo -e "${GREEN}${message}${NC}" ;;
        "DEBUG") echo -e "${BLUE}${message}${NC}" ;;
    esac
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "INFO" "Running as root - proceeding with full installation"
        return 0
    else
        log "WARN" "Not running as root - some features may not be available"
        return 1
    fi
}

# Welcome message
show_welcome() {
    cat << 'WELCOME_EOF'
  ____             _               _  ___ _   
 |  _ \  ___ _ __ | | ___  _   _  | |/ (_) |_ 
 | | | |/ _ \ '_ \| |/ _ \| | | | | ' /| | __|
 | |_| |  __/ |_) | | (_) | |_| | | . \| | |_ 
 |____/ \___| .__/|_|\___/ \__, | |_|\_\_|\__|
            |_|            |___/              

Welcome to Deploy-Kit Bootstrap!
This script will quickly set up your deployment toolkit.

WELCOME_EOF
}

# Check system requirements
check_requirements() {
    log "INFO" "Checking system requirements..."
    
    local missing_deps=()
    
    # Check for essential commands
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        log "INFO" "Please install missing dependencies and try again"
        exit 1
    fi
    
    log "INFO" "System requirements check passed"
}

# Quick dependency installation
install_quick_deps() {
    log "INFO" "Installing quick dependencies..."
    
    # Detect package manager and install basic deps
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y curl wget git jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y curl wget git jq
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y curl wget git jq
    else
        log "WARN" "Unknown package manager, skipping dependency installation"
    fi
}

# Setup basic structure
setup_basic() {
    log "INFO" "Setting up basic Deploy-Kit structure..."
    
    # Make scripts executable
    chmod +x "$SCRIPT_DIR/scripts/"*.sh 2>/dev/null || true
    
    # Create basic directories
    mkdir -p "$HOME/.deploy-kit/logs"
    mkdir -p "$HOME/.deploy-kit/backups"
    
    log "INFO" "Basic setup completed"
}

# Test Node.js installation
test_nodejs() {
    log "INFO" "Testing Node.js installation..."
    
    if command -v node &> /dev/null; then
        log "INFO" "Node.js found: $(node --version)"
        
        # Test the deploy-kit index.js
        if [[ -f "$SCRIPT_DIR/src/index.js" ]]; then
            log "INFO" "Testing Deploy-Kit Node.js interface..."
            cd "$SCRIPT_DIR"
            node src/index.js --help 2>/dev/null || log "WARN" "Node.js interface test failed"
        fi
    else
        log "WARN" "Node.js not found - install Node.js for full functionality"
    fi
}

# Test Python installation
test_python() {
    log "INFO" "Testing Python installation..."
    
    if command -v python3 &> /dev/null; then
        log "INFO" "Python3 found: $(python3 --version)"
        
        # Test the deploy-kit main.py
        if [[ -f "$SCRIPT_DIR/src/main.py" ]]; then
            log "INFO" "Testing Deploy-Kit Python interface..."
            cd "$SCRIPT_DIR"
            python3 src/main.py --help 2>/dev/null || log "WARN" "Python interface test failed"
        fi
    else
        log "WARN" "Python3 not found - install Python3 for full functionality"
    fi
}

# Create convenience aliases
create_aliases() {
    log "INFO" "Creating convenience aliases..."
    
    local alias_file="$HOME/.deploy-kit/aliases.sh"
    
    cat > "$alias_file" << ALIAS_EOF
#!/bin/bash
# Deploy-Kit convenience aliases

# Main deployment commands
alias dk-deploy="cd '$SCRIPT_DIR' && bash scripts/deploy.sh"
alias dk-restart="cd '$SCRIPT_DIR' && bash scripts/restart.sh"
alias dk-setup="cd '$SCRIPT_DIR' && bash scripts/setup.sh"
alias dk-status="cd '$SCRIPT_DIR' && node src/index.js status 2>/dev/null || python3 src/main.py status"

# Configuration shortcuts
alias dk-config="cd '$SCRIPT_DIR/config' && ls -la"
alias dk-logs="cd '$HOME/.deploy-kit/logs' && ls -la"

# Quick helpers
alias dk-help="echo 'Deploy-Kit Commands:'; echo '  dk-deploy  - Run deployment'; echo '  dk-restart - Restart services'; echo '  dk-setup   - Full setup'; echo '  dk-status  - Show status'; echo '  dk-config  - View config files'; echo '  dk-logs    - View log files'"

ALIAS_EOF
    
    # Add to bashrc if not already present
    if ! grep -q "source.*deploy-kit/aliases.sh" "$HOME/.bashrc" 2>/dev/null; then
        echo "# Deploy-Kit aliases" >> "$HOME/.bashrc"
        echo "source '$alias_file'" >> "$HOME/.bashrc"
        log "INFO" "Aliases added to ~/.bashrc"
    fi
    
    log "INFO" "Aliases created. Run 'source ~/.bashrc' or restart your shell to use them"
}

# Show next steps
show_next_steps() {
    cat << 'NEXT_EOF'

🎉 Deploy-Kit Bootstrap Complete!

Quick Start Commands:
  bash scripts/deploy.sh         # Run a deployment
  bash scripts/restart.sh        # Restart services  
  bash scripts/setup.sh          # Full system setup
  node src/index.js status       # Check status (Node.js)
  python3 src/main.py status     # Check status (Python)

Configuration:
  Edit config/config.json        # Main configuration
  Edit config/env.sample         # Environment template

For Full Installation:
  sudo bash scripts/setup.sh     # Complete system setup

Convenience Aliases (after restarting shell):
  dk-deploy                      # Quick deployment
  dk-restart                     # Quick restart
  dk-status                      # Quick status
  dk-help                        # Show all aliases

Documentation:
  All scripts include --help options
  Check the README.md for detailed information

Happy Deploying! 🚀

NEXT_EOF
}

# Main bootstrap function
main() {
    local quick_mode=false
    local install_deps=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -d|--deps)
                install_deps=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  -q, --quick    Quick setup without dependency installation"
                echo "  -d, --deps     Install dependencies"
                echo "  -h, --help     Show this help"
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    show_welcome
    
    # Check if root for full installation
    local is_root=false
    if check_root; then
        is_root=true
    fi
    
    check_requirements
    
    # Install dependencies if requested or if root
    if [[ "$install_deps" == "true" ]] || ([[ "$is_root" == "true" ]] && [[ "$quick_mode" != "true" ]]); then
        install_quick_deps
    fi
    
    setup_basic
    test_nodejs
    test_python
    create_aliases
    
    show_next_steps
    
    log "INFO" "Bootstrap completed successfully!"
}

# Run main function
main "$@"