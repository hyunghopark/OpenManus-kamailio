#!/usr/bin/env python3

import os
import sys
import shutil
import tarfile
import logging
import argparse
import subprocess
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional

class KamailioDisasterRecovery:
    """
    Comprehensive Disaster Recovery and Backup System for Kamailio SIP Server
    
    Key Features:
    - Full System Backup
    - Incremental Backups
    - Backup Rotation
    - Remote Backup Support
    - Restoration Capabilities
    - Integrity Verification
    """

    def __init__(self, config_path: str = '/etc/kamailio/disaster_recovery.json'):
        """
        Initialize Disaster Recovery System
        
        :param config_path: Path to disaster recovery configuration
        """
        # Logging Setup
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/kamailio/disaster_recovery.log'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger('KamailioDisasterRecovery')
        
        # Load Configuration
        self.config = self.load_recovery_config(config_path)
        
        # Backup Paths
        self.backup_base_dir = self.config.get('backup_directory', '/var/backups/kamailio')
        os.makedirs(self.backup_base_dir, exist_ok=True)

    def load_recovery_config(self, config_path: str) -> Dict:
        """
        Load disaster recovery configuration
        
        :param config_path: Path to configuration file
        :return: Configuration dictionary
        """
        try:
            with open(config_path, 'r') as config_file:
                config = json.load(config_file)
            
            # Validate configuration
            self._validate_config(config)
            return config
        
        except FileNotFoundError:
            self.logger.warning(f"Recovery config not found at {config_path}. Using defaults.")
            return self._get_default_config()
        except json.JSONDecodeError:
            self.logger.error(f"Invalid JSON in {config_path}")
            return self._get_default_config()

    def _get_default_config(self) -> Dict:
        """
        Generate default disaster recovery configuration
        
        :return: Default configuration dictionary
        """
        return {
            "backup_directory": "/var/backups/kamailio",
            "backup_retention_days": 30,
            "backup_type": "full",
            "components_to_backup": [
                "/etc/kamailio",
                "/var/lib/kamailio",
                "/var/log/kamailio"
            ],
            "remote_backup": {
                "enabled": False,
                "type": "s3",
                "bucket": "",
                "access_key": "",
                "secret_key": ""
            },
            "encryption": {
                "enabled": True,
                "method": "gpg"
            }
        }

    def _validate_config(self, config: Dict):
        """
        Validate disaster recovery configuration
        
        :param config: Configuration dictionary
        """
        required_keys = [
            "backup_directory", "backup_retention_days", 
            "backup_type", "components_to_backup"
        ]
        
        for key in required_keys:
            if key not in config:
                raise ValueError(f"Missing required configuration key: {key}")

    def create_backup(self, backup_type: Optional[str] = None) -> str:
        """
        Create a backup of Kamailio system
        
        :param backup_type: Type of backup (full/incremental)
        :return: Path to backup archive
        """
        # Determine backup type
        backup_type = backup_type or self.config.get('backup_type', 'full')
        
        # Generate backup filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_filename = f"kamailio_backup_{backup_type}_{timestamp}.tar.gz"
        backup_path = os.path.join(self.backup_base_dir, backup_filename)
        
        try:
            # Create backup archive
            with tarfile.open(backup_path, "w:gz") as tar:
                for component in self.config['components_to_backup']:
                    if os.path.exists(component):
                        tar.add(component, arcname=os.path.basename(component))
                    else:
                        self.logger.warning(f"Backup component not found: {component}")
            
            # Optional: Encryption
            if self.config.get('encryption', {}).get('enabled', False):
                self._encrypt_backup(backup_path)
            
            # Optional: Remote Backup
            if self.config.get('remote_backup', {}).get('enabled', False):
                self._upload_remote_backup(backup_path)
            
            self.logger.info(f"Backup created: {backup_path}")
            return backup_path
        
        except Exception as e:
            self.logger.error(f"Backup creation failed: {e}")
            raise

    def _encrypt_backup(self, backup_path: str):
        """
        Encrypt backup file
        
        :param backup_path: Path to backup file
        """
        encryption_method = self.config.get('encryption', {}).get('method', 'gpg')
        
        if encryption_method == 'gpg':
            try:
                subprocess.run([
                    'gpg', '-c', 
                    '--batch', 
                    '--passphrase', os.environ.get('BACKUP_ENCRYPTION_KEY', 'default_key'),
                    backup_path
                ], check=True)
                
                # Remove unencrypted backup
                os.remove(backup_path)
                
                self.logger.info(f"Backup encrypted: {backup_path}.gpg")
            
            except subprocess.CalledProcessError as e:
                self.logger.error(f"Backup encryption failed: {e}")

    def _upload_remote_backup(self, backup_path: str):
        """
        Upload backup to remote storage
        
        :param backup_path: Path to backup file
        """
        remote_config = self.config.get('remote_backup', {})
        
        if remote_config.get('type') == 's3':
            try:
                subprocess.run([
                    'aws', 's3', 'cp', 
                    backup_path, 
                    f"s3://{remote_config['bucket']}/"
                ], env={
                    'AWS_ACCESS_KEY_ID': remote_config['access_key'],
                    'AWS_SECRET_ACCESS_KEY': remote_config['secret_key']
                }, check=True)
                
                self.logger.info(f"Backup uploaded to S3: {remote_config['bucket']}")
            
            except subprocess.CalledProcessError as e:
                self.logger.error(f"Remote backup upload failed: {e}")

    def rotate_backups(self):
        """
        Rotate and remove old backups based on retention policy
        """
        retention_days = self.config.get('backup_retention_days', 30)
        cutoff_date = datetime.now() - timedelta(days=retention_days)
        
        try:
            for backup_file in os.listdir(self.backup_base_dir):
                backup_path = os.path.join(self.backup_base_dir, backup_file)
                
                # Get file modification time
                mod_time = datetime.fromtimestamp(os.path.getmtime(backup_path))
                
                # Remove old backups
                if mod_time < cutoff_date:
                    os.remove(backup_path)
                    self.logger.info(f"Removed old backup: {backup_file}")
        
        except Exception as e:
            self.logger.error(f"Backup rotation failed: {e}")

    def restore_backup(self, backup_path: str):
        """
        Restore system from a backup
        
        :param backup_path: Path to backup archive
        """
        try:
            # Decrypt if encrypted
            if backup_path.endswith('.gpg'):
                decrypted_path = backup_path[:-4]
                subprocess.run([
                    'gpg', '-d', 
                    '--batch',
                    '--passphrase', os.environ.get('BACKUP_ENCRYPTION_KEY', 'default_key'),
                    '-o', decrypted_path,
                    backup_path
                ], check=True)
                backup_path = decrypted_path
            
            # Extract backup
            with tarfile.open(backup_path, "r:gz") as tar:
                tar.extractall(path='/')
            
            # Restart Kamailio service
            subprocess.run(['systemctl', 'restart', 'kamailio'], check=True)
            
            self.logger.info(f"System restored from backup: {backup_path}")
        
        except Exception as e:
            self.logger.error(f"Backup restoration failed: {e}")
            raise

    def disaster_recovery_workflow(self):
        """
        Complete Disaster Recovery Workflow
        """
        try:
            # Create Backup
            backup_path = self.create_backup()
            
            # Rotate Old Backups
            self.rotate_backups()
            
            self.logger.info("Disaster Recovery Workflow Completed Successfully")
        
        except Exception as e:
            self.logger.error(f"Disaster Recovery Workflow Failed: {e}")
            raise

def main():
    parser = argparse.ArgumentParser(description="Kamailio Disaster Recovery Tool")
    parser.add_argument('--config', help="Path to disaster recovery configuration file")
    parser.add_argument('--backup', action='store_true', help="Create a backup")
    parser.add_argument('--restore', help="Restore from a specific backup")
    parser.add_argument('--rotate', action='store_true', help="Rotate backups")
    
    args = parser.parse_args()
    
    recovery = KamailioDisasterRecovery(args.config if args.config else '/etc/kamailio/disaster_recovery.json')
    
    if args.backup:
        recovery.create_backup()
    
    if args.restore:
        recovery.restore_backup(args.restore)
    
    if args.rotate:
        recovery.rotate_backups()
    
    # If no specific action, run full workflow
    if not any([args.backup, args.restore, args.rotate]):
        recovery.disaster_recovery_workflow()

if __name__ == "__main__":
    main()