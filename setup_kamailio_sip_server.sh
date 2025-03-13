#!/bin/bash

# Kamailio SIP Server with MariaDB Docker Setup Script

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Docker Compose is not installed. Please install Docker Compose.${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Prerequisites checked successfully${NC}"
}

# Function to create project structure
create_project_structure() {
    echo -e "${YELLOW}Creating project directory structure...${NC}"
    
    # Create directories
    mkdir -p kamailio-sip-server/kamailio-config
    mkdir -p kamailio-sip-server/kamailio-data
    mkdir -p kamailio-sip-server/mariadb-data
    
    cd kamailio-sip-server
    
    echo -e "${GREEN}✓ Project structure created${NC}"
}

# Function to create Docker Compose file
create_docker_compose() {
    echo -e "${YELLOW}Creating Docker Compose configuration...${NC}"
    
    cat > docker-compose.yml << EOL
version: '3.8'
services:
  mariadb:
    image: mariadb:latest
    container_name: kamailio-db
    environment:
      MYSQL_ROOT_PASSWORD: kamailio_root_pass
      MYSQL_DATABASE: kamailio
      MYSQL_USER: kamailio
      MYSQL_PASSWORD: kamailio_user_pass
    volumes:
      - ./mariadb-data:/var/lib/mysql
    ports:
      - "3306:3306"
    networks:
      - kamailio_network

  kamailio:
    image: kamailio/kamailio-ci:latest
    container_name: kamailio-server
    depends_on:
      - mariadb
    volumes:
      - ./kamailio-config:/etc/kamailio
      - ./kamailio-data:/var/lib/kamailio
    ports:
      - "5060:5060/udp"
      - "5060:5060/tcp"
      - "5061:5061/tcp"
    environment:
      - KAMAILIO_DB_HOST=mariadb
      - KAMAILIO_DB_USER=kamailio
      - KAMAILIO_DB_PASSWORD=kamailio_user_pass
      - KAMAILIO_DB_NAME=kamailio
    networks:
      - kamailio_network

networks:
  kamailio_network:
    driver: bridge
EOL

    echo -e "${GREEN}✓ Docker Compose file created${NC}"
}

# Function to create Kamailio configuration
create_kamailio_config() {
    echo -e "${YELLOW}Creating Kamailio configuration...${NC}"
    
    cat > kamailio-config/kamailio.cfg << EOL
#!KAMAILIO

#!define DBURL "mysql://kamailio:kamailio_user_pass@mariadb/kamailio"

# Global Parameters
debug=3
log_stderror=no
log_facility=LOG_LOCAL0

# Paths
mpath="/usr/lib/x86_64-linux-gnu/kamailio/modules"

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

# Database Connection
modparam("usrloc", "db_url", DBURL)
modparam("auth_db", "db_url", DBURL)

# User Location Parameters
modparam("usrloc", "db_mode", 2)

# Routing Block
request_route {
    # Max-Forwards check
    if (!mf_process_maxfwd_header("10")) {
        sl_send_reply("483", "Too Many Hops");
        exit;
    }

    # Check for registration
    if (is_method("REGISTER")) {
        # Authentication for registration
        if (!www_authenticate("kamailio.realm", "credentials_check", "1")) {
            www_challenge("kamailio.realm", "0");
            exit;
        }
        
        # Save contact
        save("location");
        exit;
    }

    # Routing for other requests
    if (!lookup("location")) {
        sl_send_reply("404", "Not Found");
        exit;
    }

    # Forward request
    forward();
    exit;
}
EOL

    echo -e "${GREEN}✓ Kamailio configuration created${NC}"
}

# Function to create database initialization script
create_db_init_script() {
    echo -e "${YELLOW}Creating database initialization script...${NC}"
    
    cat > init-kamailio-db.sh << 'EOL'
#!/bin/bash

# Wait for MariaDB to be ready
until mysqladmin ping -h mariadb -u kamailio -pkamailio_user_pass &> /dev/null; do
    echo "Waiting for MariaDB to be ready..."
    sleep 5
done

# Create Kamailio database schema
kamdbctl create

# Optional: Add initial users or configurations
# Example: Add a sample SIP user
mysql -h mariadb -u kamailio -pkamailio_user_pass kamailio << EOF
INSERT INTO subscriber (username, domain, password, ha1, ha1b, rpid) 
VALUES ('user1', 'kamailio.realm', 'user1pass', 
    MD5('user1:kamailio.realm:user1pass'), 
    MD5('user1:kamailio.realm:user1pass'), 
    NULL);
EOF

echo "Kamailio database initialized successfully!"
EOL

    chmod +x init-kamailio-db.sh

    echo -e "${GREEN}✓ Database initialization script created${NC}"
}

# Main setup function
main() {
    echo -e "${YELLOW}Starting Kamailio SIP Server with MariaDB Docker Setup${NC}"
    
    check_prerequisites
    create_project_structure
    create_docker_compose
    create_kamailio_config
    create_db_init_script
    
    echo -e "${GREEN}✓ Setup Complete!${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Navigate to the project directory: cd kamailio-sip-server"
    echo "2. Start containers: docker-compose up -d"
    echo "3. Initialize database: docker exec -it kamailio-server /init-kamailio-db.sh"
}

# Run the main function
main