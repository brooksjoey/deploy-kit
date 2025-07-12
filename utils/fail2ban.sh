#!/bin/bash

# Deploy-Kit Fail2ban Security Configuration Script
# Sets up fail2ban protection for the deployment toolkit

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if fail2ban is installed
check_fail2ban() {
    if ! command -v fail2ban-server &> /dev/null; then
        log "Installing fail2ban..."
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y fail2ban
        elif command -v yum &> /dev/null; then
            yum install -y fail2ban
        else
            error "Please install fail2ban manually"
            exit 1
        fi
    fi
}

# Create fail2ban jail for Deploy-Kit
create_deploy_kit_jail() {
    log "Creating Deploy-Kit fail2ban jail..."
    
    cat > /etc/fail2ban/jail.d/deploy-kit.conf << 'EOL'
# Deploy-Kit Fail2ban Configuration

[DEFAULT]
# Ban time: 1 hour
bantime = 3600

# Find time: 10 minutes
findtime = 600

# Max retry: 5 attempts
maxretry = 5

# Email notifications (configure as needed)
# destemail = admin@example.com
# sender = fail2ban@example.com
# action = %(action_mw)s

[deploy-kit-auth]
enabled = true
port = http,https
filter = deploy-kit-auth
logpath = /var/log/nginx/deploy-kit-access.log
maxretry = 3
bantime = 1800

[deploy-kit-admin]
enabled = true
port = http,https
filter = deploy-kit-admin
logpath = /var/log/deploy-kit/*.log
maxretry = 2
bantime = 3600

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/deploy-kit-access.log
maxretry = 6
bantime = 86400

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/deploy-kit-access.log
maxretry = 2
bantime = 86400

[nginx-noproxy]
enabled = true
port = http,https
filter = nginx-noproxy
logpath = /var/log/nginx/deploy-kit-access.log
maxretry = 2
bantime = 86400
EOL

    log "Deploy-Kit jail configuration created"
}

# Create custom filters
create_filters() {
    log "Creating custom fail2ban filters..."
    
    # Deploy-Kit authentication filter
    cat > /etc/fail2ban/filter.d/deploy-kit-auth.conf << 'EOL'
# Deploy-Kit authentication failure filter

[Definition]
failregex = ^<HOST> -.*POST.*/login.*HTTP/[0-9\.]+" 401
            ^<HOST> -.*POST.*/api/auth.*HTTP/[0-9\.]+" 401
            ^<HOST> -.*"POST.*login.*" 401
            ^<HOST> -.*Invalid credentials

ignoreregex =

[Init]
journalmatch = _SYSTEMD_UNIT=nginx.service
EOL

    # Deploy-Kit admin access filter
    cat > /etc/fail2ban/filter.d/deploy-kit-admin.conf << 'EOL'
# Deploy-Kit admin access filter

[Definition]
failregex = ^.*\[ERROR\].*Authentication failed for IP: <HOST>
            ^.*\[WARN\].*Unauthorized access attempt from <HOST>
            ^.*\[ERROR\].*Invalid API key from <HOST>

ignoreregex =

[Init]
datepattern = ^%%Y-%%m-%%d %%H:%%M:%%S
EOL

    log "Custom filters created"
}

# Configure fail2ban service
configure_service() {
    log "Configuring fail2ban service..."
    
    # Create local jail configuration
    cat > /etc/fail2ban/jail.local << 'EOL'
# Deploy-Kit Fail2ban Local Configuration

[DEFAULT]
# Ignore local IP ranges
ignoreip = 127.0.0.1/8 ::1 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12

# Ban time: 1 hour (3600 seconds)
bantime = 3600

# Find time: 10 minutes (600 seconds)
findtime = 600

# Max retry before ban
maxretry = 5

# Backend for log monitoring
backend = auto

# Log level
loglevel = INFO

# Log destination
logtarget = /var/log/fail2ban.log

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 6
bantime = 3600
EOL

    # Enable and start fail2ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log "Fail2ban service configured and started"
}

# Check fail2ban status
check_status() {
    log "Checking fail2ban status..."
    
    echo ""
    echo "=== Fail2ban Status ==="
    fail2ban-client status
    
    echo ""
    echo "=== Deploy-Kit Jails ==="
    fail2ban-client status deploy-kit-auth 2>/dev/null || echo "deploy-kit-auth: not active"
    fail2ban-client status deploy-kit-admin 2>/dev/null || echo "deploy-kit-admin: not active"
    
    echo ""
    echo "=== Recent Bans ==="
    tail -n 20 /var/log/fail2ban.log | grep "Ban\|Unban" || echo "No recent bans"
}

# Unban IP address
unban_ip() {
    local ip=$1
    if [[ -z "$ip" ]]; then
        error "IP address required"
        return 1
    fi
    
    log "Unbanning IP: $ip"
    fail2ban-client set deploy-kit-auth unbanip "$ip" 2>/dev/null || true
    fail2ban-client set deploy-kit-admin unbanip "$ip" 2>/dev/null || true
    fail2ban-client set sshd unbanip "$ip" 2>/dev/null || true
    
    log "IP $ip unbanned from all jails"
}

# Test configuration
test_config() {
    log "Testing fail2ban configuration..."
    
    if fail2ban-client reload; then
        log "Configuration test passed"
        check_status
    else
        error "Configuration test failed"
        return 1
    fi
}

# Usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -i, --install          Install and configure fail2ban"
    echo "  -s, --status           Show fail2ban status"
    echo "  -t, --test             Test configuration"
    echo "  -u, --unban IP         Unban specific IP address"
    echo "  -r, --reload           Reload fail2ban configuration"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --install           # Install and configure"
    echo "  $0 --status            # Show current status"
    echo "  $0 --unban 192.168.1.100  # Unban IP"
}

# Main function
main() {
    case "${1:-install}" in
        -i|--install|install)
            check_fail2ban
            create_deploy_kit_jail
            create_filters
            configure_service
            test_config
            log "Fail2ban setup completed successfully!"
            ;;
        -s|--status)
            check_status
            ;;
        -t|--test)
            test_config
            ;;
        -u|--unban)
            unban_ip "$2"
            ;;
        -r|--reload)
            log "Reloading fail2ban..."
            systemctl reload fail2ban
            log "Fail2ban reloaded"
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
