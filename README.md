# Deploy-Kit

A comprehensive deployment toolkit that provides both web-based management and command-line interfaces for application deployments. Deploy-Kit supports multiple programming environments and includes automated deployment scripts, service management, and monitoring capabilities.

## Features

- **Multi-Language Support**: Node.js and Python deployment interfaces
- **Web Management Panel**: PHP-based web interface for deployment management
- **Automated Deployment Scripts**: Pre-configured deployment, restart, and setup scripts
- **Service Management**: Automated service restart and health monitoring
- **Configuration Management**: JSON-based configuration with environment variable support
- **Security Features**: IP restrictions, API key authentication, and rate limiting
- **Backup Management**: Automated backup creation and retention
- **Notification Support**: Slack and email notifications for deployment events

## Quick Start

```bash
git clone https://github.com/brooksjoey/deploy-kit.git
cd deploy-kit
bash bootstrap.sh
```

For full system setup with dependencies:
```bash
sudo bash scripts/setup.sh
```

## Directory Structure

```
deploy-kit/
├── src/                    # Main application source code
│   ├── index.js           # Node.js deployment interface
│   └── main.py            # Python deployment interface
├── scripts/               # Deployment and management scripts
│   ├── deploy.sh          # Main deployment script
│   ├── restart.sh         # Service restart script
│   └── setup.sh           # System setup script
├── config/                # Configuration files
│   ├── config.json        # Main configuration
│   ├── env.sample         # Environment template
│   └── custom.ini         # Custom settings
├── deploy-panel/          # Web-based management interface
│   ├── index.php          # Main web interface
│   └── tools/             # Web-based tools
├── nginx/                 # NGINX configuration
├── php/                   # PHP-FPM configuration
└── utils/                 # Utility scripts
```

## Usage

### Command Line Interface

**Node.js Interface:**
```bash
# Run deployment
node src/index.js deploy

# Check status
node src/index.js status

# Restart services
node src/index.js restart
```

**Python Interface:**
```bash
# Run deployment
python3 src/main.py deploy

# Check status
python3 src/main.py status

# Create backup
python3 src/main.py backup
```

**Direct Script Usage:**
```bash
# Full deployment with health checks
bash scripts/deploy.sh

# Restart specific service
bash scripts/restart.sh nginx

# Show service status
bash scripts/restart.sh --status

# Complete system setup
sudo bash scripts/setup.sh
```

### Configuration

Edit `config/config.json` to customize your deployment:

```json
{
  "environment": "production",
  "deploymentPath": "/var/www/html",
  "backupEnabled": true,
  "services": ["nginx", "php-fpm", "redis-server"],
  "notifications": {
    "enabled": true,
    "slack": {
      "webhook": "your-webhook-url",
      "channel": "#deployments"
    }
  }
}
```

Create environment file from template:
```bash
cp config/env.sample .env
# Edit .env with your specific values
```

## Web Interface

The web-based management panel provides:

- **git-cloner.php**: Clone repositories via web interface
- **log-viewer.php**: View deployment and application logs
- **system-check.php**: Monitor system health and status

Access the web interface after setup at: `http://your-server/deploy-panel/`

## Installation Options

### Quick Bootstrap (User-level)
```bash
bash bootstrap.sh
```

### Full System Installation (Root-level)
```bash
sudo bash scripts/setup.sh
```

### Development Setup
```bash
bash scripts/setup.sh --dev
```

## Security Features

- IP-based access control
- API key authentication
- Rate limiting protection
- Secure configuration management
- SSL/TLS support via NGINX

## Monitoring & Notifications

- Health check endpoints
- Deployment success/failure notifications
- Service status monitoring
- Automatic backup management
- Log aggregation and viewing

## Dependencies

**Required:**
- Node.js 14+ (for Node.js interface)
- Python 3.6+ (for Python interface)
- Bash 4+ (for shell scripts)
- Git (for repository management)

**Optional (for full setup):**
- NGINX (web server)
- PHP 7.4+ (web interface)
- Redis (caching and sessions)
- systemd (service management)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- Check script help: `bash scripts/deploy.sh --help`
- View configuration: `cat config/config.json`
- Check logs: `tail -f /var/log/deploy-kit/*.log`
- Test installation: `bash bootstrap.sh --help`
