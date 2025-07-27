#!/bin/bash

echo "Compiling RDSEmployeeManager.java..."
javac -cp ".:/usr/local/lib/mysql-jdbc/mysql-connector-java.jar" RDSEmployeeManager.java

if [ $? -eq 0 ]; then
    echo "Compilation successful. Running the program..."
    java -cp ".:/usr/local/lib/mysql-jdbc/mysql-connector-java.jar" RDSEmployeeManager
else
    echo "Compilation failed!"
    exit 1
fi