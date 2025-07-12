#!/usr/bin/env python3

"""
Deploy-Kit - A simple deployment toolkit

This is the main entry point for the Python deployment toolkit.
It provides basic functionality for managing deployments including
configuration loading, service management, and deployment execution.
"""

import json
import os
import sys
import subprocess
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any


class DeployKit:
    """Main deployment toolkit class"""
    
    def __init__(self):
        """Initialize the deployment toolkit"""
        self.config_path = Path(__file__).parent.parent / 'config' / 'config.json'
        self.config = self.load_config()
        self.setup_logging()
        
    def setup_logging(self):
        """Setup logging configuration"""
        log_level = getattr(logging, self.config.get('logLevel', 'INFO').upper())
        logging.basicConfig(
            level=log_level,
            format='[%(asctime)s] [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%dT%H:%M:%S'
        )
        self.logger = logging.getLogger(__name__)
    
    def load_config(self) -> Dict[str, Any]:
        """
        Load configuration from config.json
        
        Returns:
            Dict containing configuration data
        """
        try:
            if self.config_path.exists():
                with open(self.config_path, 'r') as f:
                    return json.load(f)
            else:
                print(f"Config file not found at {self.config_path}, using defaults")
                return self.get_default_config()
        except Exception as e:
            print(f"Failed to load config: {e}")
            return self.get_default_config()
    
    def get_default_config(self) -> Dict[str, Any]:
        """
        Get default configuration
        
        Returns:
            Dict containing default configuration
        """
        return {
            'environment': 'development',
            'logLevel': 'INFO',
            'deploymentPath': '/var/www/html',
            'backupEnabled': True,
            'services': []
        }
    
    def execute_deployment(self, script_name: str = 'deploy') -> Dict[str, Any]:
        """
        Execute a deployment script
        
        Args:
            script_name: Name of the script to execute
            
        Returns:
            Dict containing execution results
        """
        self.logger.info(f"Starting deployment: {script_name}")
        
        try:
            script_path = Path(__file__).parent.parent / 'scripts' / f'{script_name}.sh'
            
            if not script_path.exists():
                raise FileNotFoundError(f"Deployment script not found: {script_path}")
            
            self.logger.info(f"Executing script: {script_path}")
            
            # Execute the deployment script
            result = subprocess.run(
                ['bash', str(script_path)],
                capture_output=True,
                text=True,
                check=True
            )
            
            self.logger.info("Deployment completed successfully")
            self.logger.info(f"Output: {result.stdout}")
            
            return {
                'success': True,
                'output': result.stdout,
                'stderr': result.stderr
            }
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Deployment failed with exit code {e.returncode}: {e.stderr}")
            return {
                'success': False,
                'error': e.stderr,
                'exit_code': e.returncode
            }
        except Exception as e:
            self.logger.error(f"Deployment failed: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_status(self) -> Dict[str, Any]:
        """
        Get deployment status
        
        Returns:
            Dict containing status information
        """
        return {
            'environment': self.config.get('environment'),
            'timestamp': datetime.now().isoformat(),
            'config': self.config,
            'services': self.config.get('services', [])
        }
    
    def restart_services(self) -> None:
        """Restart services defined in configuration"""
        self.logger.info("Restarting services...")
        
        services = self.config.get('services', [])
        if not services:
            self.logger.warning("No services configured for restart")
            return
        
        for service in services:
            try:
                self.logger.info(f"Restarting service: {service}")
                subprocess.run(
                    ['sudo', 'systemctl', 'restart', service],
                    check=True,
                    capture_output=True,
                    text=True
                )
                self.logger.info(f"Service {service} restarted successfully")
            except subprocess.CalledProcessError as e:
                self.logger.error(f"Failed to restart service {service}: {e.stderr}")
            except Exception as e:
                self.logger.error(f"Failed to restart service {service}: {str(e)}")
    
    def backup_deployment(self, backup_path: Optional[str] = None) -> Dict[str, Any]:
        """
        Create backup of current deployment
        
        Args:
            backup_path: Optional custom backup path
            
        Returns:
            Dict containing backup results
        """
        if not self.config.get('backupEnabled', True):
            self.logger.info("Backup is disabled in configuration")
            return {'success': False, 'reason': 'Backup disabled'}
        
        try:
            deployment_path = self.config.get('deploymentPath', '/var/www/html')
            if not backup_path:
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                backup_path = f"{deployment_path}_backup_{timestamp}"
            
            self.logger.info(f"Creating backup: {deployment_path} -> {backup_path}")
            
            subprocess.run(
                ['cp', '-r', deployment_path, backup_path],
                check=True,
                capture_output=True,
                text=True
            )
            
            self.logger.info(f"Backup created successfully: {backup_path}")
            return {'success': True, 'backup_path': backup_path}
            
        except Exception as e:
            self.logger.error(f"Backup failed: {str(e)}")
            return {'success': False, 'error': str(e)}


def main():
    """Main CLI interface"""
    deploy_kit = DeployKit()
    
    if len(sys.argv) < 2:
        print("""
Deploy-Kit Usage:
  python main.py deploy [script-name]  - Execute deployment script
  python main.py status                - Show deployment status
  python main.py restart               - Restart configured services
  python main.py backup [path]         - Create deployment backup

Examples:
  python main.py deploy                # Run default deploy.sh
  python main.py deploy custom         # Run custom.sh
  python main.py status                # Show current status
  python main.py restart               # Restart all services
  python main.py backup                # Create timestamped backup
        """)
        return
    
    command = sys.argv[1]
    
    if command == 'deploy':
        script_name = sys.argv[2] if len(sys.argv) > 2 else 'deploy'
        result = deploy_kit.execute_deployment(script_name)
        if not result['success']:
            sys.exit(1)
    
    elif command == 'status':
        status = deploy_kit.get_status()
        print(json.dumps(status, indent=2))
    
    elif command == 'restart':
        deploy_kit.restart_services()
    
    elif command == 'backup':
        backup_path = sys.argv[2] if len(sys.argv) > 2 else None
        result = deploy_kit.backup_deployment(backup_path)
        if not result['success']:
            sys.exit(1)
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == '__main__':
    main()