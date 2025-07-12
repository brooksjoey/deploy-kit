#!/bin/bash

# Deploy-Kit Service Restart Script
# This script manages restarting services defined in the configuration
# It includes safety checks, graceful restarts, and rollback capabilities

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/config.json"
LOG_FILE="/var/log/deploy-kit/restart.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default services to restart
DEFAULT_SERVICES=("nginx" "php-fpm" "redis-server")

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
    
    case $level in
        "ERROR") echo -e "${RED}${message}${NC}" ;;
        "WARN")  echo -e "${YELLOW}${message}${NC}" ;;
        "INFO")  echo -e "${GREEN}${message}${NC}" ;;
        "DEBUG") echo -e "${BLUE}${message}${NC}" ;;
    esac
}

# Check if running with appropriate permissions
check_permissions() {
    if ! sudo -n true 2>/dev/null; then
        log "ERROR" "This script requires sudo privileges to restart services"
        exit 1
    fi
}

# Load services from configuration
load_services() {
    local services=()
    
    if [[ -f "$CONFIG_FILE" ]] && command -v jq &> /dev/null; then
        log "INFO" "Loading services from configuration file"
        mapfile -t services < <(jq -r '.services[]?' "$CONFIG_FILE" 2>/dev/null)
        
        if [[ ${#services[@]} -eq 0 ]]; then
            log "WARN" "No services found in config, using defaults"
            services=("${DEFAULT_SERVICES[@]}")
        fi
    else
        log "WARN" "Config file not found or jq not available, using default services"
        services=("${DEFAULT_SERVICES[@]}")
    fi
    
    echo "${services[@]}"
}

# Check if service exists and is enabled
check_service() {
    local service=$1
    
    if ! systemctl list-unit-files | grep -q "^$service.service"; then
        log "WARN" "Service $service does not exist"
        return 1
    fi
    
    if ! systemctl is-enabled "$service" &>/dev/null; then
        log "WARN" "Service $service is not enabled"
        return 1
    fi
    
    return 0
}

# Get service status
get_service_status() {
    local service=$1
    
    if systemctl is-active "$service" &>/dev/null; then
        echo "active"
    elif systemctl is-failed "$service" &>/dev/null; then
        echo "failed"
    else
        echo "inactive"
    fi
}

# Wait for service to be ready
wait_for_service() {
    local service=$1
    local max_wait=${2:-30}
    local wait_time=0
    
    log "INFO" "Waiting for $service to be ready..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        if systemctl is-active "$service" &>/dev/null; then
            log "INFO" "$service is now active"
            return 0
        fi
        
        sleep 2
        ((wait_time += 2))
    done
    
    log "ERROR" "$service failed to become active within $max_wait seconds"
    return 1
}

# Gracefully restart a service
restart_service() {
    local service=$1
    local force=${2:-false}
    
    log "INFO" "Processing service: $service"
    
    # Check if service exists
    if ! check_service "$service"; then
        return 1
    fi
    
    local initial_status=$(get_service_status "$service")
    log "INFO" "Current status of $service: $initial_status"
    
    # If service is already failed and not forcing, skip
    if [[ "$initial_status" == "failed" ]] && [[ "$force" != "true" ]]; then
        log "WARN" "Service $service is in failed state, skipping (use --force to restart anyway)"
        return 1
    fi
    
    # Attempt graceful restart
    log "INFO" "Restarting $service..."
    
    if sudo systemctl restart "$service"; then
        if wait_for_service "$service"; then
            log "INFO" "$service restarted successfully"
            return 0
        else
            log "ERROR" "$service restart failed - service not ready"
            return 1
        fi
    else
        log "ERROR" "Failed to restart $service"
        return 1
    fi
}

# Restart all services
restart_all_services() {
    local force=$1
    local failed_services=()
    local services=($(load_services))
    
    log "INFO" "Starting service restart process..."
    log "INFO" "Services to restart: ${services[*]}"
    
    # Restart services in order
    for service in "${services[@]}"; do
        if ! restart_service "$service" "$force"; then
            failed_services+=("$service")
        fi
    done
    
    # Report results
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log "INFO" "All services restarted successfully"
        return 0
    else
        log "ERROR" "Failed to restart services: ${failed_services[*]}"
        return 1
    fi
}

# Restart specific service
restart_specific_service() {
    local service=$1
    local force=$2
    
    log "INFO" "Restarting specific service: $service"
    
    if restart_service "$service" "$force"; then
        log "INFO" "Service $service restarted successfully"
        return 0
    else
        log "ERROR" "Failed to restart service $service"
        return 1
    fi
}

# Show status of all configured services
show_service_status() {
    local services=($(load_services))
    
    log "INFO" "Service Status Report"
    echo "===================="
    
    for service in "${services[@]}"; do
        if check_service "$service"; then
            local status=$(get_service_status "$service")
            local color=""
            
            case $status in
                "active") color="$GREEN" ;;
                "failed") color="$RED" ;;
                *) color="$YELLOW" ;;
            esac
            
            echo -e "$service: ${color}$status${NC}"
        else
            echo -e "$service: ${RED}not found${NC}"
        fi
    done
}

# Reload service configurations
reload_services() {
    local services=($(load_services))
    
    log "INFO" "Reloading service configurations..."
    
    for service in "${services[@]}"; do
        if check_service "$service"; then
            log "INFO" "Reloading $service configuration..."
            if sudo systemctl reload "$service" 2>/dev/null; then
                log "INFO" "$service configuration reloaded"
            else
                log "WARN" "$service does not support reload, skipping"
            fi
        fi
    done
}

# Create systemd service file for deploy-kit (optional)
create_deploy_kit_service() {
    cat << 'EOF' > /tmp/deploy-kit.service
[Unit]
Description=Deploy-Kit Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/html
Environment=NODE_ENV=production
ExecStart=/usr/bin/node /opt/deploy-kit/src/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    log "INFO" "Deploy-Kit systemd service file created at /tmp/deploy-kit.service"
    log "INFO" "To install: sudo cp /tmp/deploy-kit.service /etc/systemd/system/ && sudo systemctl enable deploy-kit"
}

# Script usage
usage() {
    echo "Usage: $0 [options] [service-name]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -f, --force         Force restart even if service is failed"
    echo "  -s, --status        Show status of all services"
    echo "  -r, --reload        Reload service configurations instead of restart"
    echo "  --create-service    Create systemd service file for deploy-kit"
    echo ""
    echo "Arguments:"
    echo "  service-name        Restart only specific service (optional)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Restart all configured services"
    echo "  $0 nginx            # Restart only nginx"
    echo "  $0 --status         # Show status of all services"
    echo "  $0 --force nginx    # Force restart nginx even if failed"
    echo "  $0 --reload         # Reload all service configurations"
}

# Main function
main() {
    local force=false
    local show_status=false
    local reload_only=false
    local create_service=false
    local specific_service=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -s|--status)
                show_status=true
                shift
                ;;
            -r|--reload)
                reload_only=true
                shift
                ;;
            --create-service)
                create_service=true
                shift
                ;;
            -*)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                specific_service="$1"
                shift
                ;;
        esac
    done
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "INFO" "Deploy-Kit Service Restart Script Started"
    
    # Handle different modes
    if [[ "$create_service" == "true" ]]; then
        create_deploy_kit_service
        exit 0
    fi
    
    if [[ "$show_status" == "true" ]]; then
        show_service_status
        exit 0
    fi
    
    if [[ "$reload_only" == "true" ]]; then
        reload_services
        exit 0
    fi
    
    # Check permissions for restart operations
    check_permissions
    
    # Restart services
    if [[ -n "$specific_service" ]]; then
        restart_specific_service "$specific_service" "$force"
    else
        restart_all_services "$force"
    fi
}

# Run main function
main "$@"