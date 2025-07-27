#!/bin/bash

# Script to download and setup Java JDBC MySQL connector and related dependencies
# Run this script on your EC2 instance after setting up Java

echo "=========================================="
echo "Setting up Java MySQL JDBC Dependencies"
echo "=========================================="

# Update system packages
echo "Updating system packages..."
sudo apt-get update -y

# Install wget and curl if not already installed
echo "Installing wget and curl..."
sudo apt-get install -y wget curl unzip

# Create directories for JDBC drivers
echo "Creating directories..."
mkdir -p ~/mysql-jdbc
cd ~/mysql-jdbc

# Download MySQL Connector/J (JDBC Driver)
echo "Downloading MySQL Connector/J..."
MYSQL_CONNECTOR_VERSION="8.2.0"
MYSQL_CONNECTOR_URL="https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz"

wget $MYSQL_CONNECTOR_URL -O mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz

# Extract the connector
echo "Extracting MySQL Connector..."
tar -xzf mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz

# Find the JAR file
MYSQL_JAR=$(find . -name "mysql-connector-j-*.jar" | head -n 1)
echo "Found MySQL Connector JAR: $MYSQL_JAR"

# Copy JAR to a standard location
sudo mkdir -p /usr/local/lib/mysql-jdbc
sudo cp $MYSQL_JAR /usr/local/lib/mysql-jdbc/mysql-connector-java.jar

# Set permissions
sudo chmod 644 /usr/local/lib/mysql-jdbc/mysql-connector-java.jar

# Install MySQL client (optional, for testing connections)
echo "Installing MySQL client..."
sudo apt-get install -y mysql-client

# Create a classpath file for easy reference
echo "Creating classpath reference..."
echo "/usr/local/lib/mysql-jdbc/mysql-connector-java.jar" > ~/mysql-classpath.txt

# Verify Java installation
echo "=========================================="
echo "Verifying Java installation..."
java -version
javac -version

# Test JDBC driver
echo "=========================================="
echo "Testing JDBC driver..."
cat > TestJDBC.java << 'EOF'
public class TestJDBC {
    public static void main(String[] args) {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            System.out.println("✓ MySQL JDBC Driver loaded successfully!");
        } catch (ClassNotFoundException e) {
            System.out.println("✗ MySQL JDBC Driver not found!");
            e.printStackTrace();
        }
    }
}
EOF

# Compile and run test
javac TestJDBC.java
java -cp ".:/usr/local/lib/mysql-jdbc/mysql-connector-java.jar" TestJDBC

# Cleanup test file
rm TestJDBC.java TestJDBC.class

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo "MySQL JDBC JAR location: /usr/local/lib/mysql-jdbc/mysql-connector-java.jar"
echo ""
echo "To compile your Java program:"
echo "javac -cp \".:/usr/local/lib/mysql-jdbc/mysql-connector-java.jar\" RDSEmployeeManager.java"
echo ""
echo "To run your Java program:"
echo "java -cp \".:/usr/local/lib/mysql-jdbc/mysql-connector-java.jar\" RDSEmployeeManager"
echo ""
echo "Before running, make sure to:"
echo "1. Update the RDS endpoint in RDSEmployeeManager.java"
echo "2. Update the database name, username, and password"
echo "3. Ensure your RDS security group allows connections from this EC2 instance"
echo ""
echo "Optional: Test MySQL connection directly:"
echo "mysql -h your-rds-endpoint.region.rds.amazonaws.com -P 3306 -u your_username -p"
echo "=========================================="

# Clean up downloaded files
cd ~
rm -rf ~/mysql-jdbc