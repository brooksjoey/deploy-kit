#!/bin/bash

# Deploy-Kit Deployment Script
# This script handles the deployment process for applications
# It includes backup, code deployment, dependency installation, and service restart

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/config.json"
DEPLOYMENT_PATH="/var/www/html"
BACKUP_DIR="/opt/backups"
LOG_FILE="/var/log/deploy-kit/deploy.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root for system operations
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "Running as root - this is not recommended for security reasons"
    fi
}

# Create necessary directories
setup_directories() {
    log "INFO" "Setting up deployment directories..."
    
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$DEPLOYMENT_PATH"
    
    log "INFO" "Directories created successfully"
}

# Load configuration from config.json
load_config() {
    log "INFO" "Loading configuration from $CONFIG_FILE"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "WARN" "Config file not found, using defaults"
        return 0
    fi
    
    # Extract basic config values using jq if available
    if command -v jq &> /dev/null; then
        DEPLOYMENT_PATH=$(jq -r '.deploymentPath // "/var/www/html"' "$CONFIG_FILE")
        BACKUP_ENABLED=$(jq -r '.backupEnabled // true' "$CONFIG_FILE")
        ENVIRONMENT=$(jq -r '.environment // "production"' "$CONFIG_FILE")
        
        log "INFO" "Configuration loaded: environment=$ENVIRONMENT, deploymentPath=$DEPLOYMENT_PATH"
    else
        log "WARN" "jq not found, using default configuration"
    fi
}

# Create backup of current deployment
create_backup() {
    if [[ "$BACKUP_ENABLED" == "false" ]]; then
        log "INFO" "Backup disabled, skipping..."
        return 0
    fi
    
    log "INFO" "Creating backup of current deployment..."
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/deployment_backup_$timestamp"
    
    if [[ -d "$DEPLOYMENT_PATH" ]]; then
        cp -r "$DEPLOYMENT_PATH" "$backup_path"
        log "INFO" "Backup created: $backup_path"
        
        # Keep only last 5 backups
        find "$BACKUP_DIR" -name "deployment_backup_*" -type d | sort | head -n -5 | xargs rm -rf
    else
        log "WARN" "Deployment path $DEPLOYMENT_PATH does not exist, skipping backup"
    fi
}

# Pull latest code from git repository
deploy_code() {
    log "INFO" "Deploying code to $DEPLOYMENT_PATH..."
    
    # Check if it's a git repository
    if [[ -d "$DEPLOYMENT_PATH/.git" ]]; then
        log "INFO" "Updating existing git repository..."
        cd "$DEPLOYMENT_PATH"
        git fetch origin
        git reset --hard origin/main
    else
        log "INFO" "Deployment path is not a git repository"
        log "INFO" "You may need to manually copy files or clone repository"
        
        # Example: Clone repository if URL is provided
        # git clone https://github.com/your-repo/app.git "$DEPLOYMENT_PATH"
    fi
    
    log "INFO" "Code deployment completed"
}

# Install dependencies
install_dependencies() {
    log "INFO" "Installing dependencies..."
    
    cd "$DEPLOYMENT_PATH"
    
    # Node.js dependencies
    if [[ -f "package.json" ]]; then
        log "INFO" "Installing Node.js dependencies..."
        npm ci --production
    fi
    
    # PHP dependencies
    if [[ -f "composer.json" ]]; then
        log "INFO" "Installing PHP dependencies..."
        composer install --no-dev --optimize-autoloader
    fi
    
    # Python dependencies
    if [[ -f "requirements.txt" ]]; then
        log "INFO" "Installing Python dependencies..."
        pip3 install -r requirements.txt
    fi
    
    log "INFO" "Dependencies installation completed"
}

# Run database migrations
run_migrations() {
    log "INFO" "Running database migrations..."
    
    cd "$DEPLOYMENT_PATH"
    
    # Laravel migrations
    if [[ -f "artisan" ]]; then
        php artisan migrate --force
    fi
    
    # Django migrations
    if [[ -f "manage.py" ]]; then
        python3 manage.py migrate
    fi
    
    log "INFO" "Database migrations completed"
}

# Clear application caches
clear_caches() {
    log "INFO" "Clearing application caches..."
    
    cd "$DEPLOYMENT_PATH"
    
    # Laravel cache
    if [[ -f "artisan" ]]; then
        php artisan cache:clear
        php artisan config:cache
        php artisan route:cache
    fi
    
    # Clear system caches
    if command -v redis-cli &> /dev/null; then
        redis-cli flushdb
    fi
    
    log "INFO" "Caches cleared successfully"
}

# Restart services
restart_services() {
    log "INFO" "Restarting services..."
    
    local services=("nginx" "php-fpm" "redis-server")
    
    # Load services from config if jq is available
    if command -v jq &> /dev/null && [[ -f "$CONFIG_FILE" ]]; then
        mapfile -t services < <(jq -r '.services[]?' "$CONFIG_FILE")
    fi
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            log "INFO" "Restarting $service..."
            systemctl restart "$service"
            log "INFO" "$service restarted successfully"
        else
            log "WARN" "Service $service is not enabled or does not exist"
        fi
    done
}

# Health check
health_check() {
    log "INFO" "Performing health check..."
    
    local health_url="http://localhost/health"
    local max_attempts=5
    local attempt=1
    
    # Load health check URL from config if available
    if command -v jq &> /dev/null && [[ -f "$CONFIG_FILE" ]]; then
        health_url=$(jq -r '.deployment.healthCheckUrl // "http://localhost/health"' "$CONFIG_FILE")
    fi
    
    while [[ $attempt -le $max_attempts ]]; do
        log "INFO" "Health check attempt $attempt/$max_attempts"
        
        if curl -sf "$health_url" > /dev/null 2>&1; then
            log "INFO" "Health check passed"
            return 0
        fi
        
        log "WARN" "Health check failed, retrying in 10 seconds..."
        sleep 10
        ((attempt++))
    done
    
    log "ERROR" "Health check failed after $max_attempts attempts"
    return 1
}

# Send deployment notification
send_notification() {
    local status=$1
    local message="Deployment $status for $ENVIRONMENT environment at $(date)"
    
    log "INFO" "Sending deployment notification: $status"
    
    # You can implement notification logic here
    # Examples: Slack webhook, email, etc.
    
    echo "$message" | tee -a "/var/log/deploy-kit/notifications.log"
}

# Main deployment function
main() {
    log "INFO" "Starting deployment process..."
    
    check_permissions
    setup_directories
    load_config
    
    # Create backup before deployment
    create_backup
    
    # Send start notification
    send_notification "STARTED"
    
    # Deployment steps
    deploy_code
    install_dependencies
    run_migrations
    clear_caches
    restart_services
    
    # Health check
    if health_check; then
        log "INFO" "Deployment completed successfully!"
        send_notification "SUCCESS"
        exit 0
    else
        log "ERROR" "Deployment failed health check!"
        send_notification "FAILED"
        exit 1
    fi
}

# Script usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -e, --environment   Set environment (default: production)"
    echo "  --no-backup         Skip backup creation"
    echo "  --no-health-check   Skip health check"
    echo ""
    echo "Examples:"
    echo "  $0                          # Run full deployment"
    echo "  $0 --no-backup              # Deploy without backup"
    echo "  $0 -e staging               # Deploy to staging environment"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --no-backup)
            BACKUP_ENABLED=false
            shift
            ;;
        --no-health-check)
            SKIP_HEALTH_CHECK=true
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Run main function
main "$@"