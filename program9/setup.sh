#!/bin/bash

# Java Application Deployment Script for EC2 with RDS - FIXED VERSION
echo "========================================="
echo "Setting up Java Application on EC2 (Fixed)"
echo "========================================="

# Update system
echo "Updating system packages..."
sudo apt update -y

# Install required packages
echo "Installing required packages..."
sudo apt install -y wget curl unzip mysql-client maven git openjdk-17-jdk

# Create application directory
APP_DIR="/opt/java-todo-app"
echo "Creating application directory: $APP_DIR"
sudo mkdir -p $APP_DIR
sudo chown -R $USER:$USER $APP_DIR

# Set JAVA_HOME for current session and permanently
JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
echo "Setting up JAVA_HOME: $JAVA_HOME_PATH"
export JAVA_HOME=$JAVA_HOME_PATH
export PATH=$PATH:$JAVA_HOME/bin

# Add to /etc/environment
echo "JAVA_HOME=$JAVA_HOME_PATH" | sudo tee -a /etc/environment
echo "PATH=\"$PATH\"" | sudo tee -a /etc/environment

# Verify Java installation
echo "Java version:"
java -version

# Create database configuration file
echo "Creating database configuration..."
cat > $APP_DIR/db.properties << 'EOF'
# Database Configuration - UPDATE THESE VALUES
db.host=your-rds-endpoint.region.rds.amazonaws.com
db.name=java_todo_app
db.user=your_username
db.password=your_password
db.port=3306
db.url=jdbc:mysql://${db.host}:${db.port}/${db.name}?useSSL=true&serverTimezone=UTC
EOF

# Create Maven project structure
echo "Creating Maven project structure..."
cd $APP_DIR

# Create Maven project directories
mkdir -p src/main/java/com/todoapp/{model,dao,service,servlet,util}
mkdir -p src/main/resources
mkdir -p src/main/webapp/{WEB-INF,css,js}

# Create pom.xml with corrected Java version
echo "Creating Maven pom.xml..."
cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.todoapp</groupId>
    <artifactId>java-todo-app</artifactId>
    <version>1.0.0</version>
    <packaging>war</packaging>
    
    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <!-- Servlet API -->
        <dependency>
            <groupId>jakarta.servlet</groupId>
            <artifactId>jakarta.servlet-api</artifactId>
            <version>6.0.0</version>
            <scope>provided</scope>
        </dependency>
        
        <!-- JSP API -->
        <dependency>
            <groupId>jakarta.servlet.jsp</groupId>
            <artifactId>jakarta.servlet.jsp-api</artifactId>
            <version>3.1.1</version>
            <scope>provided</scope>
        </dependency>
        
        <!-- JSTL -->
        <dependency>
            <groupId>jakarta.servlet.jsp.jstl</groupId>
            <artifactId>jakarta.servlet.jsp.jstl-api</artifactId>
            <version>3.0.0</version>
        </dependency>
        
        <dependency>
            <groupId>org.glassfish.web</groupId>
            <artifactId>jakarta.servlet.jsp.jstl</artifactId>
            <version>3.0.1</version>
        </dependency>
        
        <!-- MySQL Connector -->
        <dependency>
            <groupId>mysql</groupId>
            <artifactId>mysql-connector-java</artifactId>
            <version>8.0.33</version>
        </dependency>
        
        <!-- JSON Processing -->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
            <version>2.15.2</version>
        </dependency>
    </dependencies>
    
    <build>
        <finalName>todo-app</finalName>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>17</source>
                    <target>17</target>
                </configuration>
            </plugin>
            
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-war-plugin</artifactId>
                <version>3.3.2</version>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Create all Java source files (same as before but with Jakarta imports)
echo "Creating database utility class..."
cat > src/main/java/com/todoapp/util/DatabaseUtil.java << 'EOF'
package com.todoapp.util;

import java.io.FileInputStream;
import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

public class DatabaseUtil {
    private static final String DB_PROPERTIES_FILE = "/opt/java-todo-app/db.properties";
    private static Properties dbProperties;
    
    static {
        loadDatabaseProperties();
    }
    
    private static void loadDatabaseProperties() {
        dbProperties = new Properties();
        try (FileInputStream fis = new FileInputStream(DB_PROPERTIES_FILE)) {
            dbProperties.load(fis);
        } catch (IOException e) {
            System.err.println("Error loading database properties: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    public static Connection getConnection() throws SQLException {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            
            String host = dbProperties.getProperty("db.host");
            String port = dbProperties.getProperty("db.port");
            String dbName = dbProperties.getProperty("db.name");
            String username = dbProperties.getProperty("db.user");
            String password = dbProperties.getProperty("db.password");
            
            String url = String.format("jdbc:mysql://%s:%s/%s?useSSL=true&serverTimezone=UTC", 
                                     host, port, dbName);
            
            return DriverManager.getConnection(url, username, password);
        } catch (ClassNotFoundException e) {
            throw new SQLException("MySQL JDBC Driver not found", e);
        }
    }
    
    public static void closeConnection(Connection conn) {
        if (conn != null) {
            try {
                conn.close();
            } catch (SQLException e) {
                System.err.println("Error closing connection: " + e.getMessage());
            }
        }
    }
}
EOF

# Create Task model
echo "Creating Task model..."
cat > src/main/java/com/todoapp/model/Task.java << 'EOF'
package com.todoapp.model;

import java.time.LocalDate;
import java.time.LocalDateTime;

public class Task {
    private int id;
    private String taskName;
    private LocalDate deadlineDate;
    private TaskStatus status;
    private LocalDateTime createdAt;
    
    public enum TaskStatus {
        PENDING, IN_PROGRESS, COMPLETED
    }
    
    // Constructors
    public Task() {}
    
    public Task(String taskName, LocalDate deadlineDate, TaskStatus status) {
        this.taskName = taskName;
        this.deadlineDate = deadlineDate;
        this.status = status;
    }
    
    // Getters and Setters
    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    
    public String getTaskName() { return taskName; }
    public void setTaskName(String taskName) { this.taskName = taskName; }
    
    public LocalDate getDeadlineDate() { return deadlineDate; }
    public void setDeadlineDate(LocalDate deadlineDate) { this.deadlineDate = deadlineDate; }
    
    public TaskStatus getStatus() { return status; }
    public void setStatus(TaskStatus status) { this.status = status; }
    
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    
    @Override
    public String toString() {
        return "Task{" +
                "id=" + id +
                ", taskName='" + taskName + '\'' +
                ", deadlineDate=" + deadlineDate +
                ", status=" + status +
                ", createdAt=" + createdAt +
                '}';
    }
}
EOF

# Create Task DAO (same as before)
echo "Creating Task DAO..."
cat > src/main/java/com/todoapp/dao/TaskDAO.java << 'EOF'
package com.todoapp.dao;

import com.todoapp.model.Task;
import com.todoapp.util.DatabaseUtil;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

public class TaskDAO {
    
    public void createTable() throws SQLException {
        String sql = """
            CREATE TABLE IF NOT EXISTS tasks (
                id INT AUTO_INCREMENT PRIMARY KEY,
                task_name VARCHAR(255) NOT NULL,
                deadline_date DATE NOT NULL,
                status ENUM('PENDING', 'IN_PROGRESS', 'COMPLETED') DEFAULT 'PENDING',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """;
        
        try (Connection conn = DatabaseUtil.getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.executeUpdate(sql);
        }
    }
    
    public boolean createTask(Task task) throws SQLException {
        String sql = "INSERT INTO tasks (task_name, deadline_date, status) VALUES (?, ?, ?)";
        
        try (Connection conn = DatabaseUtil.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {
            
            pstmt.setString(1, task.getTaskName());
            pstmt.setDate(2, Date.valueOf(task.getDeadlineDate()));
            pstmt.setString(3, task.getStatus().name());
            
            return pstmt.executeUpdate() > 0;
        }
    }
    
    public List<Task> getAllTasks() throws SQLException {
        List<Task> tasks = new ArrayList<>();
        String sql = "SELECT * FROM tasks ORDER BY created_at DESC";
        
        try (Connection conn = DatabaseUtil.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            
            while (rs.next()) {
                Task task = new Task();
                task.setId(rs.getInt("id"));
                task.setTaskName(rs.getString("task_name"));
                task.setDeadlineDate(rs.getDate("deadline_date").toLocalDate());
                task.setStatus(Task.TaskStatus.valueOf(rs.getString("status")));
                task.setCreatedAt(rs.getTimestamp("created_at").toLocalDateTime());
                tasks.add(task);
            }
        }
        return tasks;
    }
    
    public Task getTaskById(int id) throws SQLException {
        String sql = "SELECT * FROM tasks WHERE id = ?";
        
        try (Connection conn = DatabaseUtil.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {
            
            pstmt.setInt(1, id);
            ResultSet rs = pstmt.executeQuery();
            
            if (rs.next()) {
                Task task = new Task();
                task.setId(rs.getInt("id"));
                task.setTaskName(rs.getString("task_name"));
                task.setDeadlineDate(rs.getDate("deadline_date").toLocalDate());
                task.setStatus(Task.TaskStatus.valueOf(rs.getString("status")));
                task.setCreatedAt(rs.getTimestamp("created_at").toLocalDateTime());
                return task;
            }
        }
        return null;
    }
    
    public boolean updateTask(Task task) throws SQLException {
        String sql = "UPDATE tasks SET task_name = ?, deadline_date = ?, status = ? WHERE id = ?";
        
        try (Connection conn = DatabaseUtil.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {
            
            pstmt.setString(1, task.getTaskName());
            pstmt.setDate(2, Date.valueOf(task.getDeadlineDate()));
            pstmt.setString(3, task.getStatus().name());
            pstmt.setInt(4, task.getId());
            
            return pstmt.executeUpdate() > 0;
        }
    }
    
    public boolean deleteTask(int id) throws SQLException {
        String sql = "DELETE FROM tasks WHERE id = ?";
        
        try (Connection conn = DatabaseUtil.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {
            
            pstmt.setInt(1, id);
            return pstmt.executeUpdate() > 0;
        }
    }
}
EOF

# Create Task Service (same as before)
echo "Creating Task Service..."
cat > src/main/java/com/todoapp/service/TaskService.java << 'EOF'
package com.todoapp.service;

import com.todoapp.dao.TaskDAO;
import com.todoapp.model.Task;
import java.sql.SQLException;
import java.util.List;

public class TaskService {
    private TaskDAO taskDAO;
    
    public TaskService() {
        this.taskDAO = new TaskDAO();
        try {
            taskDAO.createTable();
        } catch (SQLException e) {
            System.err.println("Error creating tasks table: " + e.getMessage());
        }
    }
    
    public boolean createTask(Task task) {
        try {
            return taskDAO.createTask(task);
        } catch (SQLException e) {
            System.err.println("Error creating task: " + e.getMessage());
            return false;
        }
    }
    
    public List<Task> getAllTasks() {
        try {
            return taskDAO.getAllTasks();
        } catch (SQLException e) {
            System.err.println("Error getting all tasks: " + e.getMessage());
            return List.of();
        }
    }
    
    public Task getTaskById(int id) {
        try {
            return taskDAO.getTaskById(id);
        } catch (SQLException e) {
            System.err.println("Error getting task by id: " + e.getMessage());
            return null;
        }
    }
    
    public boolean updateTask(Task task) {
        try {
            return taskDAO.updateTask(task);
        } catch (SQLException e) {
            System.err.println("Error updating task: " + e.getMessage());
            return false;
        }
    }
    
    public boolean deleteTask(int id) {
        try {
            return taskDAO.deleteTask(id);
        } catch (SQLException e) {
            System.err.println("Error deleting task: " + e.getMessage());
            return false;
        }
    }
}
EOF

# Create Task Servlet with Jakarta imports
echo "Creating Task Servlet..."
cat > src/main/java/com/todoapp/servlet/TaskServlet.java << 'EOF'
package com.todoapp.servlet;

import com.todoapp.model.Task;
import com.todoapp.service.TaskService;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDate;
import java.util.List;

@WebServlet("/tasks")
public class TaskServlet extends HttpServlet {
    private TaskService taskService;
    
    @Override
    public void init() throws ServletException {
        taskService = new TaskService();
    }
    
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        
        String action = request.getParameter("action");
        
        if ("edit".equals(action)) {
            int id = Integer.parseInt(request.getParameter("id"));
            Task task = taskService.getTaskById(id);
            request.setAttribute("editTask", task);
        }
        
        List<Task> tasks = taskService.getAllTasks();
        request.setAttribute("tasks", tasks);
        request.getRequestDispatcher("/index.jsp").forward(request, response);
    }
    
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        
        String action = request.getParameter("action");
        String message = null;
        String error = null;
        
        try {
            switch (action) {
                case "create":
                    Task newTask = new Task();
                    newTask.setTaskName(request.getParameter("taskName"));
                    newTask.setDeadlineDate(LocalDate.parse(request.getParameter("deadlineDate")));
                    newTask.setStatus(Task.TaskStatus.valueOf(request.getParameter("status")));
                    
                    if (taskService.createTask(newTask)) {
                        message = "Task created successfully!";
                    } else {
                        error = "Unable to create task.";
                    }
                    break;
                    
                case "update":
                    Task updateTask = new Task();
                    updateTask.setId(Integer.parseInt(request.getParameter("id")));
                    updateTask.setTaskName(request.getParameter("taskName"));
                    updateTask.setDeadlineDate(LocalDate.parse(request.getParameter("deadlineDate")));
                    updateTask.setStatus(Task.TaskStatus.valueOf(request.getParameter("status")));
                    
                    if (taskService.updateTask(updateTask)) {
                        message = "Task updated successfully!";
                    } else {
                        error = "Unable to update task.";
                    }
                    break;
                    
                case "delete":
                    int deleteId = Integer.parseInt(request.getParameter("id"));
                    if (taskService.deleteTask(deleteId)) {
                        message = "Task deleted successfully!";
                    } else {
                        error = "Unable to delete task.";
                    }
                    break;
            }
        } catch (Exception e) {
            error = "An error occurred: " + e.getMessage();
        }
        
        request.setAttribute("message", message);
        request.setAttribute("error", error);
        
        // Redirect to prevent form resubmission
        response.sendRedirect("tasks");
    }
}
EOF

# Create web.xml for Jakarta
echo "Creating web.xml..."
cat > src/main/webapp/WEB-INF/web.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee 
         https://jakarta.ee/xml/ns/jakartaee/web-app_6_0.xsd"
         version="6.0">
         
    <display-name>Java Todo Application</display-name>
    
    <welcome-file-list>
        <welcome-file>tasks</welcome-file>
    </welcome-file-list>
    
</web-app>
EOF

# Download and install Tomcat 10 (latest version)
echo "Installing Apache Tomcat 10..."
cd /opt
sudo wget -q --show-progress https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.30/bin/apache-tomcat-10.1.30.tar.gz

if [ ! -f "apache-tomcat-10.1.30.tar.gz" ]; then
    echo "❌ Failed to download Tomcat. Trying alternative URL..."
    sudo wget -q --show-progress https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.30/bin/apache-tomcat-10.1.30.tar.gz
fi

if [ -f "apache-tomcat-10.1.30.tar.gz" ]; then
    sudo tar -xzf apache-tomcat-10.1.30.tar.gz
    sudo mv apache-tomcat-10.1.30 tomcat
    sudo rm apache-tomcat-10.1.30.tar.gz
    sudo chown -R $USER:$USER /opt/tomcat
    echo "✅ Tomcat installed successfully"
else
    echo "❌ Failed to download Tomcat. Installing from package manager..."
    sudo apt install -y tomcat10 tomcat10-admin
    sudo systemctl enable tomcat10
    TOMCAT_HOME="/usr/share/tomcat10"
fi

# Set executable permissions for Tomcat scripts
if [ -d "/opt/tomcat" ]; then
    sudo chmod +x /opt/tomcat/bin/*.sh
    TOMCAT_HOME="/opt/tomcat"
    
    # Create Tomcat service
    echo "Creating Tomcat service..."
    sudo tee /etc/systemd/system/tomcat.service > /dev/null << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=$JAVA_HOME_PATH
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
User=$USER
Group=$USER
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start Tomcat
    sudo systemctl daemon-reload
    sudo systemctl enable tomcat
    sudo systemctl start tomcat
    
    # Wait for Tomcat to start
    sleep 5
    
    if sudo systemctl is-active --quiet tomcat; then
        echo "✅ Tomcat service started successfully"
    else
        echo "⚠️  Tomcat service failed to start, checking logs..."
        sudo systemctl status tomcat --no-pager
    fi
    
    WEBAPPS_DIR="/opt/tomcat/webapps"
else
    TOMCAT_HOME="/usr/share/tomcat10"
    WEBAPPS_DIR="/var/lib/tomcat10/webapps"
    sudo systemctl start tomcat10
fi

# Create database setup script in the current directory
echo "Creating database setup script..."
cat > $HOME/setup_database_java.sh << 'EOF'
#!/bin/bash

echo "========================================="
echo "Java App Database Setup Script"
echo "========================================="

DB_CONFIG="/opt/java-todo-app/db.properties"

# Check if configuration needs updating
if grep -q "your-rds-endpoint" "$DB_CONFIG"; then
    echo "Please enter your RDS database credentials:"
    echo ""
    read -p "RDS Endpoint (e.g., mydb.abc123.us-east-1.rds.amazonaws.com): " db_host
    read -p "Database Name [java_todo_app]: " db_name
    read -p "Username: " db_user
    read -s -p "Password: " db_pass
    echo ""
    read -p "Port [3306]: " db_port
    
    # Set defaults
    db_name=${db_name:-java_todo_app}
    db_port=${db_port:-3306}
    
    # Update db.properties file
    cat > "$DB_CONFIG" << EOL
# Database Configuration
db.host=$db_host
db.name=$db_name
db.user=$db_user
db.password=$db_pass
db.port=$db_port
db.url=jdbc:mysql://\${db.host}:\${db.port}/\${db.name}?useSSL=true&serverTimezone=UTC
EOL
    
    echo "✅ Database credentials updated!"
else
    # Load existing configuration
    eval $(grep -v '^#' "$DB_CONFIG" | sed 's/^/export /')
fi

echo ""
echo "Testing database connection..."

# Test connection
if mysql -h"$db_host" -P"$db_port" -u"$db_user" -p"$db_pass" -e "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Database server connection successful!"
    
    # Check if database exists
    DB_EXISTS=$(mysql -h"$db_host" -P"$db_port" -u"$db_user" -p"$db_pass" -e "SHOW DATABASES LIKE '$db_name';" 2>/dev/null | grep -o "$db_name")
    
    if [[ "$DB_EXISTS" == "$db_name" ]]; then
        echo "✅ Database '$db_name' already exists."
    else
        echo "Creating database '$db_name'..."
        mysql -h"$db_host" -P"$db_port" -u"$db_user" -p"$db_pass" -e "CREATE DATABASE IF NOT EXISTS $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ Database '$db_name' created successfully!"
        else
            echo "❌ Failed to create database '$db_name'"
            exit 1
        fi
    fi
    
    echo "✅ Database setup complete!"
    echo ""
    echo "Building and deploying application..."
    
    # Build the application
    cd /opt/java-todo-app
    export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    mvn clean package -q
    
    if [ $? -eq 0 ]; then
        echo "✅ Application built successfully!"
        
        # Find the correct webapps directory
        if [ -d "/opt/tomcat/webapps" ]; then
            WEBAPPS_DIR="/opt/tomcat/webapps"
            SERVICE_NAME="tomcat"
        else
            WEBAPPS_DIR="/var/lib/tomcat10/webapps"
            SERVICE_NAME="tomcat10"
        fi
        
        # Deploy to Tomcat
        sudo cp target/todo-app.war $WEBAPPS_DIR/
        echo "✅ Application deployed to $WEBAPPS_DIR"
        
        # Restart Tomcat
        sudo systemctl restart $SERVICE_NAME
        sleep 5
        
        if sudo systemctl is-active --quiet $SERVICE_NAME; then
            echo "✅ Tomcat restarted successfully!"
            echo ""
            echo "🎉 Application deployed successfully!"
            echo "Access your app at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'your-ec2-ip'):8080/todo-app/tasks"
        else
            echo "⚠️  Tomcat failed to restart. Check logs:"
            echo "sudo systemctl status $SERVICE_NAME"
        fi
    else
        echo "❌ Failed to build application"
        exit 1
    fi
    
else
    echo "❌ Failed to connect to database server."
    echo "Please verify your RDS credentials and security group settings."
    exit 1
fi
EOF

chmod +x $HOME/setup_database_java.sh

# Set proper permissions
echo "Setting file permissions..."
sudo chown -R $USER:$USER $APP_DIR
chmod -R 755 $APP_DIR

# Get public IP more reliably
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "your-ec2-ip")

echo ""
echo "========================================="
echo "✅ Java Application Setup Complete!"
echo "========================================="
echo ""
echo "📝 Next Steps:"
echo "1. Configure your RDS database:"
echo "   $HOME/setup_database_java.sh"
echo ""
echo "🌐 Application will be accessible at:"
echo "   http://$PUBLIC_IP:8080/todo-app/tasks"
echo ""
echo "🔒 Security Group Requirements:"
echo "   - EC2: Allow HTTP (port 8080) inbound from 0.0.0.0/0"
echo "   - RDS: Allow MySQL (port 3306) from EC2 security group"
echo ""
echo "📁 Application files: $APP_DIR"
echo "🔧 Database config: $APP_DIR/db.properties"
echo "🔧 Database setup script: $HOME/setup_database_java.sh"
echo ""
echo "🛠️  Useful commands:"
echo "   - Setup database: $HOME/setup_database_java.sh"
echo "   - Restart Tomcat: sudo systemctl restart tomcat (or tomcat10)"
echo "   - View Tomcat logs: sudo tail -f /opt/tomcat/logs/catalina.out"
echo "   - Rebuild app: cd $APP_DIR && mvn clean package"
echo ""
echo "========================================="