# deploy-kit
Self-hosted, public-facing PHP deploy panel with optional Tailscale lockdown.

## Quick Start
```
git clone https://github.com/brooksjoey/deploy-kit.git && cd deploy-kit && bash bootstrap.sh
```

## Directory Layout
- `deploy-panel/`: All web-facing PHP tools
- `nginx/`: Hardened NGINX configs
- `php/`: PHP-FPM pool settings
- `utils/`: Security/Cert scripts

## Tools
- `git-cloner.php`: Clone a repo via query string
- `log-viewer.php`: View logs
- `system-check.php`: Basic health info

