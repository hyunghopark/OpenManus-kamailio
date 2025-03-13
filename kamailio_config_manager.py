#!/usr/bin/env python3

import os
import sys
import json
import yaml
import argparse
import subprocess
import shutil
import logging
from typing import Dict, Any, Optional

class KamailioConfigManager:
    """
    Comprehensive Configuration Management System for Kamailio SIP Server
    
    Features:
    - Configuration Validation
    - Template Management
    - Environment-based Configuration
    - Backup and Restoration
    - Configuration Encryption
    """

    def __init__(self, base_config_path: str = '/etc/kamailio/'):
        """
        Initialize Configuration Manager
        
        :param base_config_path: Base path for Kamailio configurations
        """
        # Logging Setup
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/kamailio/config_manager.log'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger('KamailioConfigManager')
        
        # Configuration Paths
        self.base_config_path = base_config_path
        self.config_templates_path = os.path.join(base_config_path, 'templates')
        self.config_backups_path = os.path.join(base_config_path, 'backups')
        
        # Ensure paths exist
        os.makedirs(self.config_templates_path, exist_ok=True)
        os.makedirs(self.config_backups_path, exist_ok=True)

    def load_config(self, config_path: str) -> Dict[str, Any]:
        """
        Load configuration from various formats
        
        :param config_path: Path to configuration file
        :return: Parsed configuration dictionary
        """
        try:
            file_ext = os.path.splitext(config_path)[1].lower()
            
            with open(config_path, 'r') as config_file:
                if file_ext in ['.json']:
                    return json.load(config_file)
                elif file_ext in ['.yaml', '.yml']:
                    return yaml.safe_load(config_file)
                else:
                    raise ValueError(f"Unsupported configuration format: {file_ext}")
        
        except Exception as e:
            self.logger.error(f"Configuration load error: {e}")
            raise

    def validate_config(self, config: Dict[str, Any]) -> bool:
        """
        Validate Kamailio configuration
        
        :param config: Configuration dictionary
        :return: Validation result
        """
        required_keys = [
            'sip_domain',
            'database_config',
            'network_settings',
            'security_settings'
        ]
        
        for key in required_keys:
            if key not in config:
                self.logger.error(f"Missing required configuration key: {key}")
                return False
        
        # Additional validation rules
        try:
            # Validate database configuration
            db_config = config['database_config']
            assert 'host' in db_config
            assert 'port' in db_config
            assert 'username' in db_config
        
        except AssertionError as e:
            self.logger.error(f"Invalid database configuration: {e}")
            return False
        
        return True

    def generate_kamailio_config(self, config: Dict[str, Any], output_path: Optional[str] = None) -> str:
        """
        Generate Kamailio configuration file
        
        :param config: Configuration dictionary
        :param output_path: Optional output path
        :return: Generated configuration path
        """
        if not self.validate_config(config):
            raise ValueError("Invalid configuration")
        
        # Default output path
        if not output_path:
            output_path = os.path.join(self.base_config_path, 'kamailio.cfg')
        
        # Configuration template
        config_template = f"""#!KAMAILIO

# Generated Configuration
# Domain Settings
domain={config['sip_domain']}

# Database Configuration
#!define DBURL "mysql://{config['database_config']['username']}:{config['database_config'].get('password', '')}@{config['database_config']['host']}:{config['database_config']['port']}/kamailio"

# Network Settings
listen={config['network_settings'].get('interface', 'eth0')}:{config['network_settings'].get('port', 5060)}

# Security Settings
{self._generate_security_config(config['security_settings'])}

# Routing Logic
request_route {{
    # Basic routing logic
    if (!mf_process_maxfwd_header("10")) {{
        sl_send_reply("483", "Too Many Hops");
        exit;
    }}

    # Registration handling
    if (is_method("REGISTER")) {{
        save("location");
        exit;
    }}

    # Routing
    if (!lookup("location")) {{
        sl_send_reply("404", "Not Found");
        exit;
    }}

    forward();
    exit;
}}
"""
        
        # Write configuration
        with open(output_path, 'w') as config_file:
            config_file.write(config_template)
        
        self.logger.info(f"Generated Kamailio configuration: {output_path}")
        return output_path

    def _generate_security_config(self, security_settings: Dict[str, Any]) -> str:
        """
        Generate security-related configuration
        
        :param security_settings: Security configuration dictionary
        :return: Security configuration string
        """
        security_config = []
        
        # TLS Configuration
        if security_settings.get('tls_enabled', False):
            security_config.append("""
# TLS Configuration
loadmodule "tls.so"
modparam("tls", "private_key", "/etc/kamailio/tls/server.key")
modparam("tls", "certificate", "/etc/kamailio/tls/server.crt")
""")
        
        # Authentication
        if security_settings.get('authentication_enabled', False):
            security_config.append("""
# Authentication
loadmodule "auth.so"
loadmodule "auth_db.so"
""")
        
        return "\n".join(security_config)

    def backup_config(self, config_path: str) -> str:
        """
        Create a backup of the configuration
        
        :param config_path: Path to configuration file
        :return: Backup file path
        """
        timestamp = subprocess.check_output(['date', '+%Y%m%d_%H%M%S']).decode().strip()
        backup_filename = f"kamailio_config_backup_{timestamp}.cfg"
        backup_path = os.path.join(self.config_backups_path, backup_filename)
        
        shutil.copy2(config_path, backup_path)
        self.logger.info(f"Configuration backed up: {backup_path}")
        
        return backup_path

    def restore_config(self, backup_path: str, target_path: Optional[str] = None) -> str:
        """
        Restore configuration from a backup
        
        :param backup_path: Path to backup configuration
        :param target_path: Optional target configuration path
        :return: Restored configuration path
        """
        if not target_path:
            target_path = os.path.join(self.base_config_path, 'kamailio.cfg')
        
        shutil.copy2(backup_path, target_path)
        self.logger.info(f"Configuration restored from {backup_path} to {target_path}")
        
        return target_path

def main():
    parser = argparse.ArgumentParser(description="Kamailio Configuration Manager")
    parser.add_argument('--config', help="Path to configuration file")
    parser.add_argument('--generate', action='store_true', help="Generate configuration")
    parser.add_argument('--backup', action='store_true', help="Backup current configuration")
    parser.add_argument('--restore', help="Restore configuration from backup")
    
    args = parser.parse_args()
    
    config_manager = KamailioConfigManager()
    
    if args.config and args.generate:
        config = config_manager.load_config(args.config)
        config_manager.generate_kamailio_config(config)
    
    elif args.backup:
        config_path = os.path.join(config_manager.base_config_path, 'kamailio.cfg')
        config_manager.backup_config(config_path)
    
    elif args.restore:
        config_manager.restore_config(args.restore)

if __name__ == "__main__":
    main()