#!/bin/bash

# Deploy-Kit SSL Certificate Management Script
# Automates SSL certificate generation and renewal using Let's Encrypt

set -e

# Configuration
DOMAIN=""
EMAIL=""
WEBROOT="/var/www/html"
NGINX_CONFIG="/etc/nginx/sites-available/deploy-kit"

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

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if certbot is installed
check_certbot() {
    if ! command -v certbot &> /dev/null; then
        log "Installing certbot..."
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
        elif command -v yum &> /dev/null; then
            yum install -y certbot python3-certbot-nginx
        else
            error "Please install certbot manually"
            exit 1
        fi
    fi
}

# Generate SSL certificate
generate_cert() {
    local domain=$1
    local email=$2
    
    log "Generating SSL certificate for $domain..."
    
    # Create temporary nginx config for verification
    cat > /tmp/nginx-ssl-temp.conf << EOL
server {
    listen 80;
    server_name $domain;
    location /.well-known/acme-challenge/ {
        root $WEBROOT;
    }
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOL
    
    # Backup existing config
    if [[ -f "$NGINX_CONFIG" ]]; then
        cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup"
    fi
    
    # Install temp config
    cp /tmp/nginx-ssl-temp.conf "$NGINX_CONFIG"
    nginx -t && systemctl reload nginx
    
    # Generate certificate
    certbot certonly \
        --webroot \
        --webroot-path="$WEBROOT" \
        --email "$email" \
        --agree-tos \
        --no-eff-email \
        --domains "$domain"
    
    # Update nginx config with SSL
    update_nginx_ssl "$domain"
    
    log "SSL certificate generated successfully for $domain"
}

# Update nginx configuration with SSL
update_nginx_ssl() {
    local domain=$1
    
    cat > "$NGINX_CONFIG" << EOL
server {
    listen 80;
    server_name $domain;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain;
    
    root /var/www/html/deploy-kit/deploy-panel;
    index index.php index.html;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    
    # Include security headers
    include /etc/nginx/conf.d/hardening.conf;
    
    # PHP handling
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Security
    location ~ /\. {
        deny all;
    }
    
    location ~ /(config|scripts|src)/ {
        deny all;
    }
}
EOL

    nginx -t && systemctl reload nginx
    log "Nginx configuration updated with SSL"
}

# Renew certificates
renew_certs() {
    log "Renewing SSL certificates..."
    certbot renew --quiet
    systemctl reload nginx
    log "Certificate renewal completed"
}

# Setup auto-renewal
setup_auto_renewal() {
    log "Setting up automatic certificate renewal..."
    
    # Add cron job for renewal
    cat > /etc/cron.d/certbot-deploy-kit << EOL
# Renew Deploy-Kit SSL certificates twice daily
0 2,14 * * * root certbot renew --quiet && systemctl reload nginx
EOL
    
    log "Auto-renewal configured"
}

# Usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -d, --domain DOMAIN     Domain name for SSL certificate"
    echo "  -e, --email EMAIL       Email address for Let's Encrypt"
    echo "  -r, --renew            Renew existing certificates"
    echo "  -s, --setup-renewal    Setup automatic renewal"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -d deploy.example.com -e admin@example.com"
    echo "  $0 --renew"
    echo "  $0 --setup-renewal"
}

# Main function
main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -e|--email)
                EMAIL="$2"
                shift 2
                ;;
            -r|--renew)
                check_certbot
                renew_certs
                exit 0
                ;;
            -s|--setup-renewal)
                setup_auto_renewal
                exit 0
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$DOMAIN" ]] || [[ -z "$EMAIL" ]]; then
        error "Domain and email are required"
        usage
        exit 1
    fi
    
    check_certbot
    generate_cert "$DOMAIN" "$EMAIL"
    setup_auto_renewal
    
    log "SSL setup completed successfully!"
    log "Your site should now be accessible at https://$DOMAIN"
}

main "$@"
