#!/bin/bash

# Kamailio SIP Server Security Hardening Script

# Color Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Security Configuration Functions

# 1. Generate Strong Passwords
generate_strong_password() {
    local length=${1:-16}
    local password=$(openssl rand -base64 $length | tr -dc 'A-Za-z0-9!@#$%^&*()' | head -c $length)
    echo "$password"
}

# 2. Configure TLS for SIP Communications
configure_sip_tls() {
    echo -e "${YELLOW}Configuring TLS for SIP Communications...${NC}"
    
    # Create TLS Certificates Directory
    mkdir -p /etc/kamailio/tls/certs
    
    # Generate Self-Signed Certificate
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -keyout /etc/kamailio/tls/certs/kamailio.key \
        -out /etc/kamailio/tls/certs/kamailio.crt \
        -subj "/C=US/ST=Security/L=SIPServer/O=Kamailio/CN=kamailio.local"
    
    # Update Kamailio Configuration for TLS
    cat >> /etc/kamailio/kamailio.cfg << EOL

# TLS Configuration
loadmodule "tls.so"

modparam("tls", "private_key", "/etc/kamailio/tls/certs/kamailio.key")
modparam("tls", "certificate", "/etc/kamailio/tls/certs/kamailio.crt")
modparam("tls", "verify_cert", "0")
modparam("tls", "require_cert", "0")

# TLS Listening Interfaces
listen=tls:eth0:5061
EOL

    echo -e "${GREEN}✓ TLS Configuration Complete${NC}"
}

# 3. Implement IP Reputation and Filtering
configure_ip_security() {
    echo -e "${YELLOW}Configuring IP-based Security Measures...${NC}"
    
    # Add IP Reputation Module
    cat >> /etc/kamailio/kamailio.cfg << EOL

# IP Reputation and Filtering
loadmodule "pike.so"
loadmodule "htable.so"

# Pike Module Configuration
modparam("pike", "sampling_time", 2)
modparam("pike", "reqs_per_unit", 10)
modparam("pike", "remove_latency", 4)

# Request Routing with IP Protection
route[IP_FILTER] {
    # Check for potential DoS attacks
    if (pike_check()) {
        sl_send_reply("403", "Forbidden - Too Many Requests");
        exit;
    }

    # Block known bad IP ranges (example)
    if (src_ip == "5.188.0.0/16" || src_ip == "185.143.0.0/16") {
        sl_send_reply("403", "Forbidden");
        exit;
    }
}

# Integrate IP Filter in main request route
request_route {
    route(IP_FILTER);
    # ... existing routing logic ...
}
EOL

    echo -e "${GREEN}✓ IP Security Configuration Complete${NC}"
}

# 4. Brute Force Protection
configure_brute_force_protection() {
    echo -e "${YELLOW}Configuring Brute Force Protection...${NC}"
    
    cat >> /etc/kamailio/kamailio.cfg << EOL

# Brute Force Protection
loadmodule "http.so"
loadmodule "jansson.so"

# Fail2Ban-like Mechanism
route[BRUTE_FORCE_PROTECTION] {
    # Track authentication failures
    if (!www_authenticate("kamailio.realm", "credentials_check", "1")) {
        # Increment failure counter
        $sht(a=>$src_ip) = $sht(a=>$src_ip) + 1;
        
        # Block if too many failures
        if ($sht(a=>$src_ip) > 5) {
            # Temporary block for 15 minutes
            $sht(a=>$src_ip) = 0;
            sl_send_reply("403", "Too Many Authentication Failures");
            exit;
        }
    }
}

# Integrate Brute Force Protection
request_route {
    route(BRUTE_FORCE_PROTECTION);
    # ... existing routing logic ...
}
EOL

    echo -e "${GREEN}✓ Brute Force Protection Configured${NC}"
}

# 5. Logging and Monitoring Configuration
configure_logging() {
    echo -e "${YELLOW}Configuring Advanced Logging...${NC}"
    
    cat >> /etc/kamailio/kamailio.cfg << EOL

# Advanced Logging Configuration
loadmodule "syslog.so"

# Syslog Parameters
modparam("syslog", "log_facility", "LOG_LOCAL7")
modparam("syslog", "log_level", 2)

# Detailed Logging Route
route[LOGGING] {
    # Log critical events
    if (is_method("REGISTER")) {
        syslog("LOG_ALERT", "REGISTER attempt from $src_ip");
    }
    
    if (is_method("INVITE")) {
        syslog("LOG_NOTICE", "INVITE from $fu to $tu");
    }
}

# Integrate Logging
request_route {
    route(LOGGING);
    # ... existing routing logic ...
}
EOL

    echo -e "${GREEN}✓ Advanced Logging Configured${NC}"
}

# Main Security Hardening Function
harden_kamailio() {
    echo -e "${YELLOW}Starting Kamailio Security Hardening...${NC}"
    
    configure_sip_tls
    configure_ip_security
    configure_brute_force_protection
    configure_logging
    
    echo -e "${GREEN}✓ Kamailio Security Hardening Complete!${NC}"
    echo -e "${YELLOW}Recommended Next Steps:${NC}"
    echo "1. Review and test configuration"
    echo "2. Restart Kamailio service"
    echo "3. Monitor logs for any issues"
}

# Execute Hardening
harden_kamailio