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