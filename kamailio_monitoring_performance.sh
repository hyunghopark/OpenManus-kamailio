#!/bin/bash

# Kamailio SIP Server Monitoring and Performance Tuning Script

# Color Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Performance Monitoring Configuration
configure_performance_monitoring() {
    echo -e "${YELLOW}Configuring Performance Monitoring...${NC}"
    
    # Create Monitoring Configuration Directory
    mkdir -p /etc/kamailio/monitoring

    # Prometheus Metrics Exporter Configuration
    cat > /etc/kamailio/monitoring/prometheus_exporter.cfg << EOL
# Kamailio Prometheus Metrics Exporter

# Enable Prometheus Metrics
loadmodule "prometheus.so"

# Metrics Configuration
modparam("prometheus", "server_address", "0.0.0.0:9090")
modparam("prometheus", "metrics_namespace", "kamailio")

# Exported Metrics
prometheus_metric("kamailio_registrations_total", "counter", "Total SIP Registrations")
prometheus_metric("kamailio_calls_total", "counter", "Total SIP Calls")
prometheus_metric("kamailio_active_subscribers", "gauge", "Active Subscribers")
prometheus_metric("kamailio_request_processing_time", "histogram", "Request Processing Time")
EOL

    echo -e "${GREEN}✓ Prometheus Metrics Configured${NC}"
}

# Performance Tuning Function
tune_performance() {
    echo -e "${YELLOW}Applying Performance Tuning...${NC}"
    
    # Update Kamailio Core Configuration
    cat >> /etc/kamailio/kamailio.cfg << EOL

# Performance Tuning Parameters
modparam("tm", "fr_timer", 2000)      # Forbid Timer (2 seconds)
modparam("tm", "fr_inv_timer", 4000)  # Forbid INVITE Timer (4 seconds)
modparam("tm", "max_transactions", 8192)  # Maximum Concurrent Transactions

# Connection Pooling
modparam("db_mysql", "max_connections", 50)
modparam("db_mysql", "connection_timeout", 3)

# Memory Management
modparam("core", "mem_warming", 1)
modparam("core", "mem_free_period", 60)

# Asynchronous Processing
modparam("tm", "async_workers", 4)

# Optimization for High Load
modparam("usrloc", "db_mode", 2)      # Write-through mode
modparam("usrloc", "use_domain", 1)   # Use full domain in user location
EOL

    echo -e "${GREEN}✓ Performance Tuning Applied${NC}"
}

# Advanced Monitoring Script
create_monitoring_script() {
    echo -e "${YELLOW}Creating Advanced Monitoring Script...${NC}"
    
    cat > /usr/local/bin/kamailio_monitor.sh << 'EOL'
#!/bin/bash

# Kamailio Monitoring Script

# Logging
LOG_FILE="/var/log/kamailio/monitoring.log"
mkdir -p $(dirname $LOG_FILE)

# System Resource Monitoring
log_system_resources() {
    echo "--- System Resources $(date) ---" >> $LOG_FILE
    top -bn1 | head -n 5 >> $LOG_FILE
    free -h >> $LOG_FILE
    df -h >> $LOG_FILE
}

# Kamailio Specific Metrics
log_kamailio_metrics() {
    echo "--- Kamailio Metrics $(date) ---" >> $LOG_FILE
    
    # Active Registrations
    kamctl ul show | grep "^[0-9]" | wc -l >> $LOG_FILE
    
    # Current Transactions
    kamctl stats | grep "Current" >> $LOG_FILE
}

# Performance Alerts
check_performance_alerts() {
    # Check for high load
    if [ $(uptime | cut -d"," -f4 | cut -d":" -f2 | tr -d " " | cut -d"." -f1) -gt 8 ]; then
        echo "HIGH LOAD ALERT: $(date)" >> $LOG_FILE
    fi
    
    # Check memory usage
    if [ $(free | grep Mem | awk '{print $3/$2 * 100.0}') -gt 90 ]; then
        echo "HIGH MEMORY USAGE ALERT: $(date)" >> $LOG_FILE
    fi
}

# Main Monitoring Function
main() {
    log_system_resources
    log_kamailio_metrics
    check_performance_alerts
}

# Run monitoring
main
EOL

    # Make the script executable
    chmod +x /usr/local/bin/kamailio_monitor.sh

    # Create a crontab entry for periodic monitoring
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/kamailio_monitor.sh") | crontab -

    echo -e "${GREEN}✓ Advanced Monitoring Script Created${NC}"
}

# Comprehensive Health Check
comprehensive_health_check() {
    echo -e "${YELLOW}Running Comprehensive Health Check...${NC}"
    
    # Check Kamailio Service Status
    systemctl is-active kamailio > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Kamailio Service is Running${NC}"
    else
        echo -e "${RED}✗ Kamailio Service is NOT Running${NC}"
    fi
    
    # Check Database Connectivity
    mysql -h mariadb -u kamailio -pkamailio_user_pass -e "SELECT 1" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database Connectivity Successful${NC}"
    else
        echo -e "${RED}✗ Database Connectivity Failed${NC}"
    fi
    
    # Check Open Ports
    PORTS=("5060" "5061" "3306")
    for PORT in "${PORTS[@]}"; do
        nc -z -w5 localhost $PORT > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Port $PORT is Open${NC}"
        else
            echo -e "${RED}✗ Port $PORT is Closed${NC}"
        fi
    done
}

# Main Execution Function
main() {
    echo -e "${BLUE}Kamailio Performance and Monitoring Setup${NC}"
    
    configure_performance_monitoring
    tune_performance
    create_monitoring_script
    comprehensive_health_check
    
    echo -e "${GREEN}✓ Kamailio Performance Optimization Complete!${NC}"
    echo -e "${YELLOW}Recommended Next Steps:${NC}"
    echo "1. Review monitoring logs at /var/log/kamailio/monitoring.log"
    echo "2. Monitor system performance"
    echo "3. Adjust tuning parameters as needed"
}

# Execute Main Function
main