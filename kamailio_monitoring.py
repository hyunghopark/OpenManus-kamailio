#!/usr/bin/env python3

import os
import sys
import time
import socket
import logging
import subprocess
import threading
import json
import smtplib
import requests
from email.mime.text import MIMEText
from prometheus_client import start_http_server, Gauge, Counter

class KamailioMonitor:
    def __init__(self, config_path='/etc/kamailio/monitoring.json'):
        """
        Initialize Kamailio Monitoring System
        
        Comprehensive monitoring with:
        - System Resource Tracking
        - SIP Server Metrics
        - Database Connectivity
        - Alerting Mechanisms
        """
        # Logging Configuration
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/kamailio/monitoring.log'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger('KamailioMonitor')

        # Load Configuration
        self.load_config(config_path)

        # Prometheus Metrics
        self.setup_prometheus_metrics()

    def load_config(self, config_path):
        """Load monitoring configuration"""
        try:
            with open(config_path, 'r') as config_file:
                self.config = json.load(config_file)
        except FileNotFoundError:
            self.logger.warning(f"Config file {config_path} not found. Using defaults.")
            self.config = {
                'monitoring_interval': 60,
                'alert_thresholds': {
                    'cpu_usage': 80,
                    'memory_usage': 90,
                    'disk_usage': 85
                },
                'email_alerts': {
                    'enabled': False,
                    'smtp_server': '',
                    'smtp_port': 587,
                    'sender_email': '',
                    'recipient_emails': [],
                    'username': '',
                    'password': ''
                },
                'slack_webhook': None
            }

    def setup_prometheus_metrics(self):
        """Setup Prometheus metrics for monitoring"""
        # SIP Server Metrics
        self.sip_registrations = Counter(
            'kamailio_registrations_total', 
            'Total SIP Registrations'
        )
        self.active_calls = Gauge(
            'kamailio_active_calls', 
            'Current Active SIP Calls'
        )
        
        # System Metrics
        self.cpu_usage = Gauge(
            'kamailio_cpu_usage_percent', 
            'CPU Usage Percentage'
        )
        self.memory_usage = Gauge(
            'kamailio_memory_usage_percent', 
            'Memory Usage Percentage'
        )
        self.disk_usage = Gauge(
            'kamailio_disk_usage_percent', 
            'Disk Usage Percentage'
        )

    def check_system_resources(self):
        """Monitor system resources"""
        try:
            # CPU Usage
            cpu_percent = self.get_cpu_usage()
            self.cpu_usage.set(cpu_percent)
            
            # Memory Usage
            memory_percent = self.get_memory_usage()
            self.memory_usage.set(memory_percent)
            
            # Disk Usage
            disk_percent = self.get_disk_usage()
            self.disk_usage.set(disk_percent)

            # Check Thresholds and Alert
            self.check_resource_thresholds(
                cpu_percent, memory_percent, disk_percent
            )

        except Exception as e:
            self.logger.error(f"Resource monitoring error: {e}")

    def get_cpu_usage(self):
        """Get current CPU usage percentage"""
        try:
            return float(subprocess.check_output(
                "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'", 
                shell=True
            ).decode().strip())
        except Exception as e:
            self.logger.error(f"CPU usage check failed: {e}")
            return 0

    def get_memory_usage(self):
        """Get current memory usage percentage"""
        try:
            free = subprocess.check_output("free | grep Mem", shell=True).decode().split()
            return float(free[2]) / float(free[1]) * 100
        except Exception as e:
            self.logger.error(f"Memory usage check failed: {e}")
            return 0

    def get_disk_usage(self):
        """Get current disk usage percentage"""
        try:
            disk = subprocess.check_output("df -h / | tail -1", shell=True).decode().split()
            return float(disk[4].rstrip('%'))
        except Exception as e:
            self.logger.error(f"Disk usage check failed: {e}")
            return 0

    def check_resource_thresholds(self, cpu, memory, disk):
        """Check if resources exceed thresholds and trigger alerts"""
        alerts = []
        
        thresholds = self.config['alert_thresholds']
        if cpu > thresholds['cpu_usage']:
            alerts.append(f"High CPU Usage: {cpu}%")
        
        if memory > thresholds['memory_usage']:
            alerts.append(f"High Memory Usage: {memory}%")
        
        if disk > thresholds['disk_usage']:
            alerts.append(f"High Disk Usage: {disk}%")
        
        if alerts:
            self.send_alerts(alerts)

    def send_alerts(self, alerts):
        """Send alerts via configured channels"""
        alert_message = "\n".join(alerts)
        
        # Email Alerts
        if self.config['email_alerts']['enabled']:
            self.send_email_alert(alert_message)
        
        # Slack Alerts
        if self.config['slack_webhook']:
            self.send_slack_alert(alert_message)

    def send_email_alert(self, message):
        """Send email alerts"""
        try:
            email_config = self.config['email_alerts']
            msg = MIMEText(message)
            msg['Subject'] = "Kamailio Server Alert"
            msg['From'] = email_config['sender_email']
            msg['To'] = ", ".join(email_config['recipient_emails'])

            with smtplib.SMTP(email_config['smtp_server'], email_config['smtp_port']) as server:
                server.starttls()
                server.login(email_config['username'], email_config['password'])
                server.send_message(msg)
        except Exception as e:
            self.logger.error(f"Email alert failed: {e}")

    def send_slack_alert(self, message):
        """Send alerts to Slack"""
        try:
            webhook_url = self.config['slack_webhook']
            payload = {
                "text": f"🚨 Kamailio Server Alert:\n{message}"
            }
            requests.post(webhook_url, json=payload)
        except Exception as e:
            self.logger.error(f"Slack alert failed: {e}")

    def check_kamailio_service(self):
        """Check Kamailio service status"""
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', 'kamailio'], 
                capture_output=True, text=True
            )
            if result.returncode != 0:
                self.send_alerts(["Kamailio Service is Down"])
        except Exception as e:
            self.logger.error(f"Service check failed: {e}")

    def monitor(self):
        """Main monitoring loop"""
        # Start Prometheus metrics server
        start_http_server(9090)
        
        self.logger.info("Kamailio Monitoring Started")
        
        while True:
            try:
                # System Resource Monitoring
                self.check_system_resources()
                
                # Service Status Check
                self.check_kamailio_service()
                
                # Sleep for configured interval
                time.sleep(self.config.get('monitoring_interval', 60))
            
            except Exception as e:
                self.logger.error(f"Monitoring loop error: {e}")
                time.sleep(30)  # Prevent rapid error cycling

def main():
    monitor = KamailioMonitor()
    monitor.monitor()

if __name__ == "__main__":
    main()