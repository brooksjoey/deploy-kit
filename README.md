# Deploy Kit

A comprehensive deployment toolkit designed to streamline and simplify your application deployment process.

## Features

- **Cross-Platform Compatibility**: Works on various Linux distributions and web server environments
- **Customizable Deployment Scripts**: Flexible configuration and deployment automation
- **Error Handling and Logging**: Built-in log viewing and system monitoring capabilities  
- **Scalable for various deployment sizes**: From single applications to complex multi-service deployments

## Installation

### Prerequisites

- PHP (version 7.4 or higher)
- Web server (Apache or Nginx)
- Git
- Bash shell environment

### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/brooksjoey/deploy-kit.git
   ```

2. Navigate to the project directory:
   ```bash
   cd deploy-kit
   ```

3. Run the automated setup script:
   ```bash
   bash bootstrap.sh
   ```

## Usage

### Basic Example

1. Configure deployment settings in the `config/` directory files.
2. Access the web-based deployment panel through your configured web server.
3. Use the built-in tools for repository management and system monitoring.

### Available Tools

- **Git Cloner**: Clone repositories via web interface
- **Log Viewer**: Monitor application and system logs
- **System Check**: View basic health and system information

### Advanced Deployment

- Configure custom PHP-FPM pools in `php/fpm-pool.conf`
- Set up hardened Nginx configurations using provided templates
- Implement security measures with fail2ban and SSL certificates
- Customize environment variables in `config/env.sample`

## Project Structure

```plaintext
deploy-kit/
│
├── /deploy-panel/      # Web-facing PHP deployment tools
│   ├── index.php       # Main dashboard
│   └── /tools/         # Individual utility tools
├── /config/            # Configuration files and templates
├── /nginx/             # Nginx configuration files
├── /php/               # PHP-FPM configuration
├── /utils/             # Security and utility scripts
├── bootstrap.sh        # Automated setup script
├── README.md           # Documentation
└── LICENSE             # License file
```

## Contributing

- Fork the repository.
- Create a new branch:
   ```bash
   git checkout -b feature/YourFeatureName
   ```
- Commit your changes:
   ```bash
   git commit -m "Add your message here"
   ```
- Push to your branch:
   ```bash
   git push origin feature/YourFeatureName
   ```
- Submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

- **Issues**: [GitHub Issues](https://github.com/brooksjoey/deploy-kit/issues)
- **Repository**: [https://github.com/brooksjoey/deploy-kit](https://github.com/brooksjoey/deploy-kit)

