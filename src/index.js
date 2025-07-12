#!/usr/bin/env node

/**
 * Deploy-Kit - A simple deployment toolkit
 * 
 * This is the main entry point for the Node.js deployment toolkit.
 * It provides basic functionality for managing deployments including
 * configuration loading, service management, and deployment execution.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class DeployKit {
    constructor() {
        this.configPath = path.join(__dirname, '../config/config.json');
        this.config = this.loadConfig();
        this.logLevel = this.config.logLevel || 'info';
    }

    /**
     * Load configuration from config.json
     * @returns {Object} Configuration object
     */
    loadConfig() {
        try {
            if (fs.existsSync(this.configPath)) {
                const configData = fs.readFileSync(this.configPath, 'utf8');
                return JSON.parse(configData);
            } else {
                this.log('warn', 'Config file not found, using defaults');
                return this.getDefaultConfig();
            }
        } catch (error) {
            this.log('error', `Failed to load config: ${error.message}`);
            return this.getDefaultConfig();
        }
    }

    /**
     * Get default configuration
     * @returns {Object} Default configuration
     */
    getDefaultConfig() {
        return {
            environment: 'development',
            logLevel: 'info',
            deploymentPath: '/var/www/html',
            backupEnabled: true,
            services: []
        };
    }

    /**
     * Log messages with different levels
     * @param {string} level - Log level (info, warn, error)
     * @param {string} message - Message to log
     */
    log(level, message) {
        const timestamp = new Date().toISOString();
        console.log(`[${timestamp}] [${level.toUpperCase()}] ${message}`);
    }

    /**
     * Execute a deployment script
     * @param {string} scriptName - Name of the script to execute
     */
    async executeDeployment(scriptName = 'deploy') {
        this.log('info', `Starting deployment: ${scriptName}`);
        
        try {
            const scriptPath = path.join(__dirname, '../scripts', `${scriptName}.sh`);
            
            if (!fs.existsSync(scriptPath)) {
                throw new Error(`Deployment script not found: ${scriptPath}`);
            }

            this.log('info', `Executing script: ${scriptPath}`);
            
            // Execute the deployment script
            const output = execSync(`bash ${scriptPath}`, { 
                encoding: 'utf8',
                stdio: 'pipe'
            });
            
            this.log('info', 'Deployment completed successfully');
            this.log('info', `Output: ${output}`);
            
            return { success: true, output };
        } catch (error) {
            this.log('error', `Deployment failed: ${error.message}`);
            return { success: false, error: error.message };
        }
    }

    /**
     * Get deployment status
     * @returns {Object} Status information
     */
    getStatus() {
        return {
            environment: this.config.environment,
            timestamp: new Date().toISOString(),
            config: this.config,
            services: this.config.services || []
        };
    }

    /**
     * Restart services defined in configuration
     */
    async restartServices() {
        this.log('info', 'Restarting services...');
        
        if (!this.config.services || this.config.services.length === 0) {
            this.log('warn', 'No services configured for restart');
            return;
        }

        for (const service of this.config.services) {
            try {
                this.log('info', `Restarting service: ${service}`);
                execSync(`sudo systemctl restart ${service}`, { encoding: 'utf8' });
                this.log('info', `Service ${service} restarted successfully`);
            } catch (error) {
                this.log('error', `Failed to restart service ${service}: ${error.message}`);
            }
        }
    }
}

// CLI interface
if (require.main === module) {
    const deployKit = new DeployKit();
    const args = process.argv.slice(2);
    const command = args[0];

    switch (command) {
        case 'deploy':
            const scriptName = args[1] || 'deploy';
            deployKit.executeDeployment(scriptName);
            break;
        
        case 'status':
            console.log(JSON.stringify(deployKit.getStatus(), null, 2));
            break;
        
        case 'restart':
            deployKit.restartServices();
            break;
        
        default:
            console.log(`
Deploy-Kit Usage:
  node index.js deploy [script-name]  - Execute deployment script
  node index.js status                - Show deployment status  
  node index.js restart               - Restart configured services

Examples:
  node index.js deploy                # Run default deploy.sh
  node index.js deploy custom         # Run custom.sh
  node index.js status                # Show current status
  node index.js restart               # Restart all services
            `);
    }
}

module.exports = DeployKit;