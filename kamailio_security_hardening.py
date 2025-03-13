#!/usr/bin/env python3

import os
import sys
import subprocess
import logging
import json
import re
import secrets
import hashlib
import argparse
import ipaddress
from typing import Dict, List, Optional

class KamailioSecurityHardener:
    """
    Comprehensive Security Hardening for Kamailio SIP Server
    
    Key Security Features:
    - TLS/SSL Configuration
    - Authentication Mechanisms
    - Network Security
    - Brute Force Protection
    - Logging and Auditing
    """

    def __init__(self, config_path: str = '/etc/kamailio/security.json'):
        """
        Initialize Security Hardening System
        
        :param config_path: Path to security configuration
        """
        # Logging Setup
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/kamailio/security_hardening.log'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger('KamailioSecurityHardener')
        
        # Load Configuration
        self.config = self.load_security_config(config_path)
        
        # Paths
        self.kamailio_config_path = '/etc/kamailio/kamailio.cfg'
        self.tls_dir = '/etc/kamailio/tls'
        os.makedirs(self.tls_dir, exist_ok=True)

    def load_security_config(self, config_path: str) -> Dict:
        """
        Load security configuration
        
        :param config_path: Path to security configuration file
        :return: Security configuration dictionary
        """
        try:
            with open(config_path, 'r') as config_file:
                config = json.load(config_file)
            
            # Validate configuration
            self._validate_config(config)
            return config
        
        except FileNotFoundError:
            self.logger.warning(f"Security config not found at {config_path}. Using defaults.")
            return self._get_default_config()
        except json.JSONDecodeError:
            self.logger.error(f"Invalid JSON in {config_path}")
            return self._get_default_config()

    def _get_default_config(self) -> Dict:
        """
        Generate default security configuration
        
        :return: Default security configuration dictionary
        """
        return {
            "tls": {
                "enabled": True,
                "min_protocol": "TLSv1.2",
                "cipher_list": "HIGH:!aNULL:!MD5:!3DES"
            },
            "authentication": {
                "method": "digest",
                "realm": "kamailio.local"
            },
            "network_security": {
                "allowed_networks": ["192.168.0.0/16", "10.0.0.0/8"],
                "blocked_ips": []
            },
            "brute_force_protection": {
                "max_attempts": 5,
                "block_duration": 3600  # 1 hour
            },
            "logging": {
                "level": "INFO",
                "sensitive_data_masking": True
            }
        }

    def _validate_config(self, config: Dict):
        """
        Validate security configuration
        
        :param config: Security configuration dictionary
        """
        required_keys = [
            "tls", "authentication", 
            "network_security", "brute_force_protection", 
            "logging"
        ]
        
        for key in required_keys:
            if key not in config:
                raise ValueError(f"Missing required security configuration key: {key}")

    def generate_tls_certificates(self):
        """
        Generate TLS/SSL Certificates for Secure Communication
        """
        try:
            # Generate Private Key
            subprocess.run([
                'openssl', 'genrsa', 
                '-out', os.path.join(self.tls_dir, 'kamailio.key'), 
                '2048'
            ], check=True)
            
            # Generate Certificate Signing Request
            subprocess.run([
                'openssl', 'req', '-new', 
                '-key', os.path.join(self.tls_dir, 'kamailio.key'),
                '-out', os.path.join(self.tls_dir, 'kamailio.csr'),
                '-subj', '/CN=kamailio.local/O=SIPServer/C=US'
            ], check=True)
            
            # Self-sign Certificate
            subprocess.run([
                'openssl', 'x509', '-req', 
                '-days', '365',
                '-in', os.path.join(self.tls_dir, 'kamailio.csr'),
                '-signkey', os.path.join(self.tls_dir, 'kamailio.key'),
                '-out', os.path.join(self.tls_dir, 'kamailio.crt')
            ], check=True)
            
            self.logger.info("TLS Certificates generated successfully")
        
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Certificate generation failed: {e}")
            raise

    def configure_network_security(self):
        """
        Configure Network Security Rules
        """
        network_config = self.config['network_security']
        
        # IPTables Rules for Network Protection
        allowed_networks = network_config.get('allowed_networks', [])
        blocked_ips = network_config.get('blocked_ips', [])
        
        # Flush existing rules
        subprocess.run(['iptables', '-F'], check=True)
        
        # Default DROP policy
        subprocess.run(['iptables', '-P', 'INPUT', 'DROP'], check=True)
        subprocess.run(['iptables', '-P', 'FORWARD', 'DROP'], check=True)
        
        # Allow localhost
        subprocess.run(['iptables', '-A', 'INPUT', '-i', 'lo', '-j', 'ACCEPT'], check=True)
        
        # Allow established connections
        subprocess.run(['iptables', '-A', 'INPUT', '-m', 'state', '--state', 'ESTABLISHED,RELATED', '-j', 'ACCEPT'], check=True)
        
        # Allow specific networks
        for network in allowed_networks:
            try:
                subprocess.run([
                    'iptables', '-A', 'INPUT', 
                    '-s', network, 
                    '-p', 'tcp', 
                    '--dport', '5060', 
                    '-j', 'ACCEPT'
                ], check=True)
            except subprocess.CalledProcessError:
                self.logger.error(f"Failed to add network rule for {network}")
        
        # Block specific IPs
        for ip in blocked_ips:
            try:
                subprocess.run(['iptables', '-A', 'INPUT', '-s', ip, '-j', 'DROP'], check=True)
            except subprocess.CalledProcessError:
                self.logger.error(f"Failed to block IP {ip}")
        
        self.logger.info("Network security rules configured")

    def configure_authentication(self):
        """
        Configure Advanced Authentication Mechanisms
        """
        auth_config = self.config['authentication']
        
        # Generate Realm
        realm = auth_config.get('realm', 'kamailio.local')
        
        # Update Kamailio Configuration
        with open(self.kamailio_config_path, 'r') as cfg_file:
            config_content = cfg_file.read()
        
        # Add authentication modules
        if 'loadmodule "auth.so"' not in config_content:
            config_content += "\n# Authentication Modules\n"
            config_content += "loadmodule \"auth.so\"\n"
            config_content += "loadmodule \"auth_db.so\"\n"
        
        # Configure authentication parameters
        config_content += f"\n# Authentication Configuration\n"
        config_content += f"modparam(\"auth_db\", \"db_url\", DBURL)\n"
        config_content += f"modparam(\"auth_db\", \"realm_column\", \"realm\")\n"
        config_content += f"modparam(\"auth_db\", \"password_column\", \"password\")\n"
        
        # Write updated configuration
        with open(self.kamailio_config_path, 'w') as cfg_file:
            cfg_file.write(config_content)
        
        self.logger.info("Authentication configuration updated")

    def implement_brute_force_protection(self):
        """
        Implement Brute Force Protection Mechanisms
        """
        bf_config = self.config['brute_force_protection']
        
        # Update Kamailio Configuration
        with open(self.kamailio_config_path, 'r') as cfg_file:
            config_content = cfg_file.read()
        
        # Add pike module for brute force protection
        if 'loadmodule "pike.so"' not in config_content:
            config_content += "\n# Brute Force Protection\n"
            config_content += "loadmodule \"pike.so\"\n"
        
        # Configure pike module
        config_content += "\n# Pike Module Configuration\n"
        config_content += f"modparam(\"pike\", \"sampling_time\", 2)\n"
        config_content += f"modparam(\"pike\", \"reqs_per_unit\", {bf_config.get('max_attempts', 5)})\n"
        config_content += f"modparam(\"pike\", \"remove_latency\", {bf_config.get('block_duration', 3600) // 60})\n"
        
        # Add pike check to request route
        config_content += """
# Brute Force Protection in Request Route
route[PIKE_CHECK] {
    # Check for potential DoS attacks
    if (pike_check()) {
        sl_send_reply("403", "Forbidden - Too Many Requests");
        exit;
    }
}

# Integrate Pike Check in Main Route
request_route {
    route(PIKE_CHECK);
    # ... existing routing logic ...
}
"""
        
        # Write updated configuration
        with open(self.kamailio_config_path, 'w') as cfg_file:
            cfg_file.write(config_content)
        
        self.logger.info("Brute force protection configured")

    def harden_system(self):
        """
        Comprehensive System Hardening
        """
        try:
            # Generate TLS Certificates
            self.generate_tls_certificates()
            
            # Configure Network Security
            self.configure_network_security()
            
            # Configure Authentication
            self.configure_authentication()
            
            # Implement Brute Force Protection
            self.implement_brute_force_protection()
            
            self.logger.info("Kamailio Security Hardening Complete")
        
        except Exception as e:
            self.logger.error(f"Security hardening failed: {e}")
            raise

def main():
    parser = argparse.ArgumentParser(description="Kamailio Security Hardening Tool")
    parser.add_argument('--config', help="Path to security configuration file")
    parser.add_argument('--harden', action='store_true', help="Apply security hardening")
    
    args = parser.parse_args()
    
    hardener = KamailioSecurityHardener(args.config if args.config else '/etc/kamailio/security.json')
    
    if args.harden:
        hardener.harden_system()

if __name__ == "__main__":
    main()