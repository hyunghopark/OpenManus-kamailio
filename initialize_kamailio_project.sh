#!/bin/bash

# Kamailio SIP Server Project Initializer

# Color Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project Configuration
PROJECT_NAME="kamailio-sip-server"
PROJECT_ROOT="/opt/${PROJECT_NAME}"

# Initialization Function
initialize_project() {
    clear
    echo -e "${BLUE}🚀 Kamailio SIP Server Project Initializer${NC}"
    
    # Create Project Directory Structure
    create_project_structure
    
    # Copy Initialization Files
    copy_project_files
    
    # Set Permissions
    set_file_permissions
    
    # Generate Unique Configurations
    generate_unique_configs
    
    # Final Setup
    finalize_setup
}

# Create Project Directory Structure
create_project_structure() {
    echo -e "${YELLOW}Creating Project Directory Structure...${NC}"
    
    mkdir -p "${PROJECT_ROOT}"/{config,data,logs,scripts,certs,backups}
    mkdir -p "${PROJECT_ROOT}/config"/{kamailio,mariadb,tls}
    mkdir -p "${PROJECT_ROOT}/data"/{kamailio,mariadb}
    
    echo -e "${GREEN}✓ Project Directory Structure Created${NC}"
}

# Copy Project Files
copy_project_files() {
    echo -e "${YELLOW}Copying Project Configuration Files...${NC}"
    
    # Copy previously created files
    cp /tmp/docker-compose.yml "${PROJECT_ROOT}/docker-compose.yml"
    cp /tmp/kamailio.cfg "${PROJECT_ROOT}/config/kamailio/kamailio.cfg"
    cp /tmp/kamailio_deployment_manager.sh "${PROJECT_ROOT}/scripts/deployment_manager.sh"
    cp /tmp/kamailio_monitoring_performance.sh "${PROJECT_ROOT}/scripts/monitoring.sh"
    cp /tmp/kamailio_security_config.sh "${PROJECT_ROOT}/scripts/security_config.sh"
    cp /tmp/kamailio_test_suite.sh "${PROJECT_ROOT}/scripts/test_suite.sh"
    cp /tmp/DOCUMENTATION.md "${PROJECT_ROOT}/DOCUMENTATION.md"
    cp /tmp/KAMAILIO_README.md "${PROJECT_ROOT}/README.md"
    
    echo -e "${GREEN}✓ Project Files Copied Successfully${NC}"
}

# Set File Permissions
set_file_permissions() {
    echo -e "${YELLOW}Setting File Permissions...${NC}"
    
    # Make scripts executable
    chmod +x "${PROJECT_ROOT}/scripts"/*.sh
    
    # Secure sensitive configuration files
    chmod 600 "${PROJECT_ROOT}/config"/*/*.cfg
    chmod 600 "${PROJECT_ROOT}/config"/*/*.yml
    
    echo -e "${GREEN}✓ File Permissions Set${NC}"
}

# Generate Unique Configurations
generate_unique_configs() {
    echo -e "${YELLOW}Generating Unique Configurations...${NC}"
    
    # Generate Unique Passwords
    ROOT_DB_PASSWORD=$(openssl rand -base64 16)
    KAMAILIO_DB_PASSWORD=$(openssl rand -base64 16)
    
    # Create .env file
    cat > "${PROJECT_ROOT}/.env" << EOL
# Database Configuration
MYSQL_ROOT_PASSWORD=${ROOT_DB_PASSWORD}
MYSQL_USER_PASSWORD=${KAMAILIO_DB_PASSWORD}

# SIP Server Configuration
SIP_DOMAIN=kamailio.local
KAMAILIO_REALM=kamailio.local
EOL

    # Generate SSL Certificates
    openssl req -x509 -newkey rsa:4096 -keyout "${PROJECT_ROOT}/certs/kamailio.key" \
        -out "${PROJECT_ROOT}/certs/kamailio.crt" -days 365 -nodes \
        -subj "/C=US/ST=SIPServer/L=Network/O=Kamailio/CN=kamailio.local"
    
    echo -e "${GREEN}✓ Unique Configurations Generated${NC}"
}

# Finalize Setup
finalize_setup() {
    echo -e "${YELLOW}Finalizing Project Setup...${NC}"
    
    # Create README with project details
    cat >> "${PROJECT_ROOT}/README.md" << EOL

## Project Initialization Details

- **Project Root**: ${PROJECT_ROOT}
- **Initialization Date**: $(date)
- **Unique Domain**: kamailio.local

### Next Steps
1. Review configurations in \`config/\` directory
2. Run deployment script: \`./scripts/deployment_manager.sh\`
3. Run test suite: \`./scripts/test_suite.sh\`

EOL

    # Create symbolic links for easy access
    ln -sf "${PROJECT_ROOT}/scripts/deployment_manager.sh" "/usr/local/bin/kamailio-deploy"
    ln -sf "${PROJECT_ROOT}/scripts/test_suite.sh" "/usr/local/bin/kamailio-test"
    
    echo -e "${GREEN}✓ Project Setup Complete!${NC}"
    
    # Display Summary
    display_project_summary
}

# Display Project Summary
display_project_summary() {
    echo -e "\n${BLUE}🎉 Kamailio SIP Server Project Initialized ${NC}"
    echo -e "${GREEN}Project Location:${NC} ${PROJECT_ROOT}"
    echo -e "${GREEN}Deployment Command:${NC} kamailio-deploy"
    echo -e "${GREEN}Test Suite Command:${NC} kamailio-test"
    
    # Security Warning
    echo -e "\n${YELLOW}⚠️ Security Notice:${NC}"
    echo "- Review and customize configurations"
    echo "- Secure your .env file"
    echo "- Implement additional security measures"
}

# Execute Initialization
initialize_project