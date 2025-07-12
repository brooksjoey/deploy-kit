#!/bin/bash

# Deploy-Kit Setup Script
# This script handles the initial setup and configuration of the deployment toolkit
# It installs dependencies, configures services, and prepares the environment

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/config.json"
LOG_FILE="/var/log/deploy-kit/setup.log"

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
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
    
    case $level in
        "ERROR") echo -e "${RED}${message}${NC}" ;;
        "WARN")  echo -e "${YELLOW}${message}${NC}" ;;
        "INFO")  echo -e "${GREEN}${message}${NC}" ;;
        "DEBUG") echo -e "${BLUE}${message}${NC}" ;;
    esac
}

# Detect operating system
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log "ERROR" "Cannot detect operating system"
        exit 1
    fi
    
    log "INFO" "Detected OS: $OS $OS_VERSION"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "INFO" "Running as root"
        return 0
    else
        log "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

# Update system packages
update_system() {
    log "INFO" "Updating system packages..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get upgrade -y
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf update -y
            else
                yum update -y
            fi
            ;;
        *)
            log "WARN" "Unknown OS, skipping system update"
            ;;
    esac
    
    log "INFO" "System packages updated"
}

# Install required packages
install_packages() {
    log "INFO" "Installing required packages..."
    
    local packages=""
    
    case $OS in
        ubuntu|debian)
            packages="curl wget git jq nginx php-fpm php-cli php-json php-mbstring composer nodejs npm python3 python3-pip redis-server"
            apt-get install -y $packages
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                packages="curl wget git jq nginx php-fpm php-cli php-json php-mbstring composer nodejs npm python3 python3-pip redis"
                dnf install -y $packages
            else
                packages="curl wget git jq nginx php-fpm php-cli php-json php-mbstring nodejs npm python3 python3-pip redis"
                yum install -y $packages
                # Install composer manually for CentOS/RHEL
                install_composer_manual
            fi
            ;;
        *)
            log "ERROR" "Unsupported OS for automatic package installation"
            exit 1
            ;;
    esac
    
    log "INFO" "Required packages installed"
}

# Install Composer manually (for systems without package)
install_composer_manual() {
    log "INFO" "Installing Composer manually..."
    
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    
    log "INFO" "Composer installed successfully"
}

# Install Node.js using NodeSource (if not available via package manager)
install_nodejs() {
    if ! command -v node &> /dev/null; then
        log "INFO" "Installing Node.js via NodeSource..."
        
        curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
        apt-get install -y nodejs
        
        log "INFO" "Node.js installed successfully"
    else
        log "INFO" "Node.js already installed: $(node --version)"
    fi
}

# Setup project directories
setup_directories() {
    log "INFO" "Setting up project directories..."
    
    # Create deployment directories
    mkdir -p /var/www/html
    mkdir -p /opt/deploy-kit
    mkdir -p /etc/deploy-kit
    mkdir -p /var/log/deploy-kit
    mkdir -p /opt/backups
    
    # Copy project files to /opt/deploy-kit
    cp -r "$PROJECT_ROOT"/* /opt/deploy-kit/
    
    # Set proper permissions
    chown -R www-data:www-data /var/www/html
    chown -R root:root /opt/deploy-kit
    chown -R www-data:www-data /var/log/deploy-kit
    chown -R www-data:www-data /opt/backups
    
    # Make scripts executable
    chmod +x /opt/deploy-kit/scripts/*.sh
    chmod +x /opt/deploy-kit/bootstrap.sh
    
    log "INFO" "Project directories setup completed"
}

# Configure NGINX
configure_nginx() {
    log "INFO" "Configuring NGINX..."
    
    # Copy NGINX configuration if it exists
    if [[ -f "$PROJECT_ROOT/nginx/deploy_kit.conf" ]]; then
        cp "$PROJECT_ROOT/nginx/deploy_kit.conf" /etc/nginx/sites-available/deploy-kit
        ln -sf /etc/nginx/sites-available/deploy-kit /etc/nginx/sites-enabled/
    fi
    
    # Copy hardening configuration if it exists
    if [[ -f "$PROJECT_ROOT/nginx/hardening.conf" ]]; then
        cp "$PROJECT_ROOT/nginx/hardening.conf" /etc/nginx/conf.d/
    fi
    
    # Test NGINX configuration
    if nginx -t; then
        log "INFO" "NGINX configuration is valid"
        systemctl enable nginx
        systemctl restart nginx
    else
        log "ERROR" "NGINX configuration is invalid"
        return 1
    fi
    
    log "INFO" "NGINX configuration completed"
}

# Configure PHP-FPM
configure_php_fpm() {
    log "INFO" "Configuring PHP-FPM..."
    
    # Copy PHP-FPM pool configuration if it exists
    if [[ -f "$PROJECT_ROOT/php/fpm-pool.conf" ]]; then
        cp "$PROJECT_ROOT/php/fpm-pool.conf" /etc/php/*/fpm/pool.d/deploy-kit.conf
    fi
    
    # Enable and start PHP-FPM
    systemctl enable php*-fpm
    systemctl restart php*-fpm
    
    log "INFO" "PHP-FPM configuration completed"
}

# Configure Redis
configure_redis() {
    log "INFO" "Configuring Redis..."
    
    # Enable and start Redis
    systemctl enable redis-server || systemctl enable redis
    systemctl start redis-server || systemctl start redis
    
    log "INFO" "Redis configuration completed"
}

# Install Python dependencies for deploy-kit
install_python_deps() {
    log "INFO" "Installing Python dependencies..."
    
    # Create requirements.txt if it doesn't exist
    if [[ ! -f "$PROJECT_ROOT/requirements.txt" ]]; then
        cat > "$PROJECT_ROOT/requirements.txt" << EOF
requests>=2.28.0
pyyaml>=6.0
click>=8.0
colorama>=0.4.4
EOF
    fi
    
    pip3 install -r "$PROJECT_ROOT/requirements.txt"
    
    log "INFO" "Python dependencies installed"
}

# Install Node.js dependencies for deploy-kit
install_node_deps() {
    log "INFO" "Installing Node.js dependencies..."
    
    # Create package.json if it doesn't exist
    if [[ ! -f "$PROJECT_ROOT/package.json" ]]; then
        cat > "$PROJECT_ROOT/package.json" << EOF
{
  "name": "deploy-kit",
  "version": "1.0.0",
  "description": "A simple deployment toolkit",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "deploy": "node src/index.js deploy",
    "status": "node src/index.js status",
    "restart": "node src/index.js restart"
  },
  "dependencies": {},
  "devDependencies": {},
  "engines": {
    "node": ">=14.0.0"
  }
}
EOF
    fi
    
    cd "$PROJECT_ROOT"
    npm install --production
    
    log "INFO" "Node.js dependencies installed"
}

# Setup environment file
setup_environment() {
    log "INFO" "Setting up environment configuration..."
    
    local env_file="/etc/deploy-kit/.env"
    
    if [[ ! -f "$env_file" ]]; then
        cat > "$env_file" << EOF
# Deploy-Kit Environment Configuration
ENVIRONMENT=production
LOG_LEVEL=info

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=deploy_kit_db
DB_USER=deploy_user
DB_PASSWORD=changeme

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Security
ADMIN_API_KEY=changeme
DEPLOY_API_KEY=changeme

# Notifications
SLACK_WEBHOOK_URL=
SMTP_USER=
SMTP_PASSWORD=

# Git Configuration
DEPLOY_KEY_PATH=/etc/deploy-kit/deploy_key
GITHUB_WEBHOOK_SECRET=changeme
EOF
    fi
    
    # Set proper permissions
    chmod 600 "$env_file"
    chown root:root "$env_file"
    
    log "INFO" "Environment configuration created at $env_file"
    log "WARN" "Please update the environment file with your actual configuration"
}

# Create systemd services
create_systemd_services() {
    log "INFO" "Creating systemd services..."
    
    # Deploy-Kit main service
    cat > /etc/systemd/system/deploy-kit.service << EOF
[Unit]
Description=Deploy-Kit Service
After=network.target nginx.service redis.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/deploy-kit
Environment=NODE_ENV=production
EnvironmentFile=/etc/deploy-kit/.env
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Deploy-Kit timer for periodic tasks
    cat > /etc/systemd/system/deploy-kit-cleanup.service << EOF
[Unit]
Description=Deploy-Kit Cleanup Service
After=network.target

[Service]
Type=oneshot
User=www-data
Group=www-data
WorkingDirectory=/opt/deploy-kit
ExecStart=/bin/bash scripts/cleanup.sh
EOF

    cat > /etc/systemd/system/deploy-kit-cleanup.timer << EOF
[Unit]
Description=Deploy-Kit Cleanup Timer
Requires=deploy-kit-cleanup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd and enable services
    systemctl daemon-reload
    systemctl enable deploy-kit.service
    systemctl enable deploy-kit-cleanup.timer
    
    log "INFO" "Systemd services created and enabled"
}

# Setup firewall rules
setup_firewall() {
    log "INFO" "Setting up firewall rules..."
    
    if command -v ufw &> /dev/null; then
        # UFW (Ubuntu/Debian)
        ufw allow ssh
        ufw allow http
        ufw allow https
        ufw --force enable
    elif command -v firewall-cmd &> /dev/null; then
        # firewalld (CentOS/RHEL/Fedora)
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        systemctl enable firewalld
    else
        log "WARN" "No supported firewall found, skipping firewall setup"
        return 0
    fi
    
    log "INFO" "Firewall rules configured"
}

# Final verification
verify_installation() {
    log "INFO" "Verifying installation..."
    
    local errors=0
    
    # Check required commands
    local commands=("node" "python3" "php" "nginx" "redis-cli" "git" "jq")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required command not found: $cmd"
            ((errors++))
        fi
    done
    
    # Check services
    local services=("nginx" "php*-fpm" "redis-server")
    for service in "${services[@]}"; do
        if ! systemctl is-active "$service" &>/dev/null; then
            log "WARN" "Service not active: $service"
        fi
    done
    
    # Check directories
    local directories=("/opt/deploy-kit" "/var/log/deploy-kit" "/etc/deploy-kit")
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log "ERROR" "Required directory not found: $dir"
            ((errors++))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        log "INFO" "Installation verification completed successfully"
        return 0
    else
        log "ERROR" "Installation verification failed with $errors errors"
        return 1
    fi
}

# Print post-installation instructions
print_instructions() {
    log "INFO" "Installation completed!"
    
    cat << EOF

==============================================
Deploy-Kit Setup Complete!
==============================================

Next Steps:
1. Edit the configuration file: /etc/deploy-kit/.env
2. Update the JSON config: /opt/deploy-kit/config/config.json
3. Start the Deploy-Kit service: systemctl start deploy-kit
4. Test the installation: cd /opt/deploy-kit && node src/index.js status

Available Commands:
- deploy-kit deploy      # Run deployment
- deploy-kit status      # Show status
- deploy-kit restart     # Restart services

Configuration Files:
- Main config: /opt/deploy-kit/config/config.json
- Environment: /etc/deploy-kit/.env
- NGINX: /etc/nginx/sites-available/deploy-kit

Log Files:
- Setup: /var/log/deploy-kit/setup.log
- Deploy: /var/log/deploy-kit/deploy.log
- Restart: /var/log/deploy-kit/restart.log

For help: /opt/deploy-kit/scripts/deploy.sh --help

==============================================

EOF
}

# Script usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  --skip-packages     Skip package installation"
    echo "  --skip-services     Skip service configuration"
    echo "  --skip-firewall     Skip firewall setup"
    echo "  --dev               Setup for development environment"
    echo ""
    echo "Examples:"
    echo "  $0                  # Full setup"
    echo "  $0 --skip-firewall  # Setup without firewall configuration"
    echo "  $0 --dev            # Development setup"
}

# Main function
main() {
    local skip_packages=false
    local skip_services=false
    local skip_firewall=false
    local dev_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            --skip-packages)
                skip_packages=true
                shift
                ;;
            --skip-services)
                skip_services=true
                shift
                ;;
            --skip-firewall)
                skip_firewall=true
                shift
                ;;
            --dev)
                dev_mode=true
                shift
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log "INFO" "Deploy-Kit Setup Script Started"
    
    # Check prerequisites
    check_root
    detect_os
    
    # Main setup steps
    if [[ "$skip_packages" != "true" ]]; then
        update_system
        install_packages
        install_nodejs
        install_python_deps
        install_node_deps
    fi
    
    setup_directories
    setup_environment
    
    if [[ "$skip_services" != "true" ]]; then
        configure_nginx
        configure_php_fpm
        configure_redis
        create_systemd_services
    fi
    
    if [[ "$skip_firewall" != "true" ]] && [[ "$dev_mode" != "true" ]]; then
        setup_firewall
    fi
    
    # Verification and completion
    verify_installation
    print_instructions
    
    log "INFO" "Deploy-Kit setup completed successfully!"
}

# Run main function
main "$@"