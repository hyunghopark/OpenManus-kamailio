#!/bin/bash

# Kamailio SIP Server Deployment and Management Script

# Color Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global Variables
PROJECT_DIR="/opt/kamailio-sip-server"
CONFIG_DIR="${PROJECT_DIR}/config"
BACKUP_DIR="${PROJECT_DIR}/backups"
LOG_FILE="${PROJECT_DIR}/deployment.log"

# Logging Function
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Prerequisite Check
check_prerequisites() {
    log_message "INFO" "Checking system prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_message "ERROR" "Docker is not installed"
        return 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_message "ERROR" "Docker Compose is not installed"
        return 1
    fi
    
    # Check required system packages
    local packages=("openssl" "curl" "git")
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            log_message "WARNING" "$pkg is not installed"
        fi
    done
    
    log_message "INFO" "Prerequisites check completed"
    return 0
}

# Project Initialization
initialize_project() {
    log_message "INFO" "Initializing Kamailio SIP Server project..."
    
    # Create project directory structure
    mkdir -p "${PROJECT_DIR}"/{config,data,backups,logs}
    mkdir -p "${CONFIG_DIR}"/{kamailio,tls,ssl}
    
    # Create Docker Compose File
    cat > "${PROJECT_DIR}/docker-compose.yml" << EOL
version: '3.8'
services:
  mariadb:
    image: mariadb:latest
    container_name: kamailio-db
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-kamailio_root_pass}
      MYSQL_DATABASE: kamailio
      MYSQL_USER: kamailio
      MYSQL_PASSWORD: ${MYSQL_USER_PASSWORD:-kamailio_user_pass}
    volumes:
      - ${PROJECT_DIR}/data/mariadb:/var/lib/mysql
      - ${PROJECT_DIR}/config/mariadb:/docker-entrypoint-initdb.d
    ports:
      - "3306:3306"
    networks:
      - kamailio_network
    restart: unless-stopped

  kamailio:
    image: kamailio/kamailio-ci:latest
    container_name: kamailio-server
    depends_on:
      - mariadb
    volumes:
      - ${PROJECT_DIR}/config/kamailio:/etc/kamailio
      - ${PROJECT_DIR}/data/kamailio:/var/lib/kamailio
      - ${PROJECT_DIR}/logs:/var/log/kamailio
    ports:
      - "5060:5060/udp"
      - "5060:5060/tcp"
      - "5061:5061/tcp"
    environment:
      - KAMAILIO_DB_HOST=mariadb
      - KAMAILIO_DB_USER=kamailio
      - KAMAILIO_DB_PASSWORD=${MYSQL_USER_PASSWORD:-kamailio_user_pass}
      - KAMAILIO_DB_NAME=kamailio
    networks:
      - kamailio_network
    restart: unless-stopped

networks:
  kamailio_network:
    driver: bridge
EOL

    log_message "INFO" "Docker Compose file created successfully"
}

# SSL/TLS Certificate Generation
generate_ssl_certificates() {
    log_message "INFO" "Generating SSL/TLS Certificates..."
    
    # Generate CA Key and Certificate
    openssl genrsa -out "${CONFIG_DIR}/tls/ca.key" 4096
    openssl req -new -x509 -days 365 -key "${CONFIG_DIR}/tls/ca.key" \
        -subj "/C=US/ST=SIPServer/L=Network/O=Kamailio/CN=RootCA" \
        -out "${CONFIG_DIR}/tls/ca.crt"
    
    # Generate Server Key and Certificate
    openssl genrsa -out "${CONFIG_DIR}/tls/server.key" 2048
    openssl req -new -key "${CONFIG_DIR}/tls/server.key" \
        -subj "/C=US/ST=SIPServer/L=Network/O=Kamailio/CN=kamailio.local" \
        -out "${CONFIG_DIR}/tls/server.csr"
    
    # Self-sign the server certificate
    openssl x509 -req -days 365 -in "${CONFIG_DIR}/tls/server.csr" \
        -CA "${CONFIG_DIR}/tls/ca.crt" -CAkey "${CONFIG_DIR}/tls/ca.key" \
        -CAcreateserial -out "${CONFIG_DIR}/tls/server.crt"
    
    log_message "INFO" "SSL/TLS Certificates generated successfully"
}

# Kamailio Configuration
configure_kamailio() {
    log_message "INFO" "Configuring Kamailio..."
    
    # Basic Kamailio Configuration
    cat > "${CONFIG_DIR}/kamailio/kamailio.cfg" << EOL
#!KAMAILIO

# Global Parameters
debug=3
log_stderror=no
log_facility=LOG_LOCAL0

# Paths
mpath="/usr/lib/x86_64-linux-gnu/kamailio/modules"

# Database Configuration
#!define DBURL "mysql://kamailio:kamailio_user_pass@mariadb/kamailio"

# Module Loading
loadmodule "db_mysql.so"
loadmodule "sl.so"
loadmodule "tm.so"
loadmodule "rr.so"
loadmodule "maxfwd.so"
loadmodule "usrloc.so"
loadmodule "registrar.so"
loadmodule "textops.so"
loadmodule "siputils.so"
loadmodule "xlog.so"
loadmodule "auth.so"
loadmodule "auth_db.so"
loadmodule "tls.so"

# TLS Configuration
modparam("tls", "private_key", "/etc/kamailio/tls/server.key")
modparam("tls", "certificate", "/etc/kamailio/tls/server.crt")
modparam("tls", "verify_cert", "0")

# Routing Logic
request_route {
    # Max-Forwards check
    if (!mf_process_maxfwd_header("10")) {
        sl_send_reply("483", "Too Many Hops");
        exit;
    }

    # Registration Handling
    if (is_method("REGISTER")) {
        save("location");
        exit;
    }

    # Routing
    if (!lookup("location")) {
        sl_send_reply("404", "Not Found");
        exit;
    }

    forward();
    exit;
}
EOL

    log_message "INFO" "Kamailio configuration created successfully"
}

# Deployment Function
deploy() {
    check_prerequisites
    initialize_project
    generate_ssl_certificates
    configure_kamailio
    
    # Pull latest images
    docker-compose -f "${PROJECT_DIR}/docker-compose.yml" pull
    
    # Start services
    docker-compose -f "${PROJECT_DIR}/docker-compose.yml" up -d
    
    log_message "INFO" "Kamailio SIP Server deployed successfully"
}

# Backup Function
backup() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${BACKUP_DIR}/kamailio_backup_${timestamp}.tar.gz"
    
    log_message "INFO" "Creating backup..."
    tar -czvf "${backup_file}" "${PROJECT_DIR}"
    
    log_message "INFO" "Backup created: ${backup_file}"
}

# Restore Function
restore() {
    local backup_file=$1
    
    if [ ! -f "${backup_file}" ]; then
        log_message "ERROR" "Backup file not found"
        return 1
    fi
    
    log_message "INFO" "Restoring from backup: ${backup_file}"
    tar -xzvf "${backup_file}" -C "/"
    
    # Restart services
    docker-compose -f "${PROJECT_DIR}/docker-compose.yml" down
    docker-compose -f "${PROJECT_DIR}/docker-compose.yml" up -d
    
    log_message "INFO" "Restoration complete"
}

# Main Menu
main() {
    echo -e "${BLUE}Kamailio SIP Server Deployment Manager${NC}"
    echo "1. Deploy Kamailio"
    echo "2. Backup Configuration"
    echo "3. Restore Configuration"
    echo "4. Exit"
    
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1) deploy ;;
        2) backup ;;
        3) 
            read -p "Enter backup file path: " backup_path
            restore "${backup_path}"
            ;;
        4) exit 0 ;;
        *) 
            echo -e "${RED}Invalid option${NC}"
            main
            ;;
    esac
}

# Execute Main Function
main