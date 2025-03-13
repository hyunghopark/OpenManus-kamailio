#!/bin/bash

# Comprehensive Kamailio SIP Server Test Suite

# Color Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global Variables
TEST_LOG="/tmp/kamailio_test_results.log"
KAMAILIO_CONTAINER="kamailio-server"
MARIADB_CONTAINER="kamailio-db"

# Logging Function
log_test() {
    local status=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[${timestamp}] [${status}] ${message}" | tee -a "${TEST_LOG}"
}

# Prerequisite Check
check_prerequisites() {
    log_test "INFO" "Checking test prerequisites..."
    
    # Check required testing tools
    local tools=("docker" "nc" "curl" "sipp" "mysql")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_test "ERROR" "$tool is not installed"
            return 1
        fi
    done
    
    log_test "INFO" "All prerequisites checked successfully"
    return 0
}

# Container Health Check
container_health_check() {
    log_test "INFO" "Performing Container Health Check..."
    
    # Check Kamailio Container
    docker ps | grep "${KAMAILIO_CONTAINER}" &> /dev/null
    if [ $? -eq 0 ]; then
        log_test "PASS" "Kamailio Container is Running"
    else
        log_test "FAIL" "Kamailio Container is NOT Running"
        return 1
    fi
    
    # Check MariaDB Container
    docker ps | grep "${MARIADB_CONTAINER}" &> /dev/null
    if [ $? -eq 0 ]; then
        log_test "PASS" "MariaDB Container is Running"
    else
        log_test "FAIL" "MariaDB Container is NOT Running"
        return 1
    fi
    
    return 0
}

# Network Connectivity Test
network_connectivity_test() {
    log_test "INFO" "Running Network Connectivity Tests..."
    
    # Test SIP Ports
    local sip_ports=("5060/udp" "5060/tcp" "5061/tcp")
    for port in "${sip_ports[@]}"; do
        nc -z -w5 localhost $(echo "$port" | cut -d'/' -f1) &> /dev/null
        if [ $? -eq 0 ]; then
            log_test "PASS" "SIP Port $port is Open"
        else
            log_test "FAIL" "SIP Port $port is Closed"
        fi
    done
    
    # Test Database Port
    nc -z -w5 localhost 3306 &> /dev/null
    if [ $? -eq 0 ]; then
        log_test "PASS" "Database Port 3306 is Open"
    else
        log_test "FAIL" "Database Port 3306 is Closed"
    fi
}

# Database Connectivity Test
database_connectivity_test() {
    log_test "INFO" "Testing Database Connectivity..."
    
    # Get database credentials from Docker Compose or environment
    local db_host="localhost"
    local db_user="kamailio"
    local db_pass="kamailio_user_pass"
    local db_name="kamailio"
    
    # Test MySQL Connection
    mysql -h "${db_host}" -u "${db_user}" -p"${db_pass}" "${db_name}" -e "SELECT 1" &> /dev/null
    if [ $? -eq 0 ]; then
        log_test "PASS" "Database Connection Successful"
        
        # Additional Database Tests
        local table_count=$(mysql -h "${db_host}" -u "${db_user}" -p"${db_pass}" "${db_name}" -se "SHOW TABLES;" | wc -l)
        log_test "INFO" "Number of Tables in Database: ${table_count}"
    else
        log_test "FAIL" "Database Connection Failed"
    fi
}

# SIP Registration Simulation Test
sip_registration_test() {
    log_test "INFO" "Running SIP Registration Simulation..."
    
    # Prepare SIPp Scenario
    cat > /tmp/register.xml << EOL
<?xml version="1.0" encoding="ISO-8859-1" ?>
<!DOCTYPE scenario SYSTEM "sipp.dtd">
<scenario name="Registration">
    <send>
        <![CDATA[
            REGISTER sip:kamailio.local SIP/2.0
            Via: SIP/2.0/UDP [local_ip]:[local_port];branch=[branch]
            From: <sip:test_user@kamailio.local>;tag=[call_number]
            To: <sip:test_user@kamailio.local>
            Call-ID: [call_id]
            CSeq: 1 REGISTER
            Contact: <sip:test_user@[local_ip]:[local_port]>
            Max-Forwards: 70
            Expires: 3600
            Content-Length: 0
        ]]>
    </send>
    
    <recv response="200" rtd="true">
    </recv>
</scenario>
EOL

    # Run SIPp Registration Test
    sipp -sf /tmp/register.xml -m 10 localhost:5060 &> /dev/null
    if [ $? -eq 0 ]; then
        log_test "PASS" "SIP Registration Test Successful"
    else
        log_test "FAIL" "SIP Registration Test Failed"
    fi
}

# Performance Stress Test
performance_stress_test() {
    log_test "INFO" "Running Performance Stress Test..."
    
    # Simulate multiple concurrent registrations
    sipp -sf /tmp/register.xml -m 100 -r 10 localhost:5060 &> /dev/null
    if [ $? -eq 0 ]; then
        log_test "PASS" "Performance Stress Test Completed Successfully"
    else
        log_test "FAIL" "Performance Stress Test Failed"
    fi
}

# Main Test Suite
run_test_suite() {
    echo -e "${BLUE}Kamailio SIP Server Test Suite${NC}"
    
    # Clear previous test log
    > "${TEST_LOG}"
    
    # Run Tests
    check_prerequisites
    container_health_check
    network_connectivity_test
    database_connectivity_test
    sip_registration_test
    performance_stress_test
    
    # Generate Test Report
    generate_test_report
}

# Generate Test Report
generate_test_report() {
    echo -e "\n${BLUE}Test Suite Report${NC}"
    echo "Full test results available in: ${TEST_LOG}"
    
    # Count test results
    local passed=$(grep -c "PASS" "${TEST_LOG}")
    local failed=$(grep -c "FAIL" "${TEST_LOG}")
    local total=$((passed + failed))
    
    echo -e "${GREEN}Passed Tests: ${passed}/${total}${NC}"
    echo -e "${RED}Failed Tests: ${failed}/${total}${NC}"
    
    # Highlight critical failures
    if [ $failed -gt 0 ]; then
        echo -e "\n${RED}CRITICAL FAILURES DETECTED${NC}"
        grep "FAIL" "${TEST_LOG}"
    fi
}

# Execute Test Suite
run_test_suite