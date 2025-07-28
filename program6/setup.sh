#!/bin/bash

# PHP Todo Application Setup Script for EC2
echo "========================================="
echo "Setting up PHP Todo Application on EC2"
echo "========================================="

# Update system
echo "Updating system packages..."
sudo apt update -y

# Install Apache, PHP, and MySQL client
echo "Installing Apache, PHP, and required extensions..."
sudo apt install -y apache2 php libapache2-mod-php php-mysql php-pdo mysql-client

# Enable and start Apache
echo "Starting Apache service..."
sudo systemctl enable apache2
sudo systemctl start apache2

# Create application directory
echo "Setting up application directory..."
sudo mkdir -p /var/www/html/todo-app
sudo chown -R $USER:$USER /var/www/html/todo-app

# Create directory structure
mkdir -p /var/www/html/todo-app/config
mkdir -p /var/www/html/todo-app/models

# Create environment configuration file
echo "Creating environment configuration..."
cat > /var/www/html/todo-app/config/.env << 'EOF'
# Database Configuration - UPDATE THESE VALUES
DB_HOST=your-rds-endpoint.region.rds.amazonaws.com
DB_NAME=todo_app
DB_USER=your_username
DB_PASS=your_password
DB_PORT=3306
EOF

# Function to create database
create_database() {
    echo ""
    echo "========================================="
    echo "Database Setup"
    echo "========================================="
    
    # Load environment variables
    source /var/www/html/todo-app/config/.env
    
    # Check if database credentials are configured
    if [[ "$DB_HOST" == "your-rds-endpoint.region.rds.amazonaws.com" ]]; then
        echo "⚠️  Database credentials not configured yet."
        echo "Please update /var/www/html/todo-app/config/.env with your RDS details first."
        echo ""
        echo "After updating credentials, run:"
        echo "bash setup_database.sh"
        return 1
    fi
    
    echo "Testing database connection..."
    
    # Test connection without database name first
    if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1;" > /dev/null 2>&1; then
        echo "✅ Database connection successful!"
        
        # Check if database exists
        DB_EXISTS=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES LIKE '$DB_NAME';" | grep -o "$DB_NAME")
        
        if [[ "$DB_EXISTS" == "$DB_NAME" ]]; then
            echo "✅ Database '$DB_NAME' already exists."
        else
            echo "Creating database '$DB_NAME'..."
            mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            
            if [ $? -eq 0 ]; then
                echo "✅ Database '$DB_NAME' created successfully!"
            else
                echo "❌ Failed to create database '$DB_NAME'"
                return 1
            fi
        fi
        
        # Test connection to the specific database
        if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" > /dev/null 2>&1; then
            echo "✅ Connection to database '$DB_NAME' successful!"
            echo "🎉 Database setup complete!"
            return 0
        else
            echo "❌ Failed to connect to database '$DB_NAME'"
            return 1
        fi
    else
        echo "❌ Failed to connect to database server."
        echo "Please check your RDS credentials in /var/www/html/todo-app/config/.env"
        return 1
    fi
}

# Create separate database setup script
echo "Creating database setup script..."
cat > setup_database.sh << 'EOF'
#!/bin/bash

echo "========================================="
echo "Database Setup Script"
echo "========================================="

# Load environment variables
if [ ! -f "/var/www/html/todo-app/config/.env" ]; then
    echo "❌ Environment file not found!"
    echo "Please run the main setup.sh script first."
    exit 1
fi

source /var/www/html/todo-app/config/.env

# Prompt for database credentials if not set
if [[ "$DB_HOST" == "your-rds-endpoint.region.rds.amazonaws.com" ]]; then
    echo "Please enter your RDS database credentials:"
    echo ""
    read -p "RDS Endpoint (e.g., mydb.abc123.us-east-1.rds.amazonaws.com): " db_host
    read -p "Database Name [todo_app]: " db_name
    read -p "Username: " db_user
    read -s -p "Password: " db_pass
    echo ""
    read -p "Port [3306]: " db_port
    
    # Set defaults
    db_name=${db_name:-todo_app}
    db_port=${db_port:-3306}
    
    # Update .env file
    cat > /var/www/html/todo-app/config/.env << EOL
# Database Configuration
DB_HOST=$db_host
DB_NAME=$db_name
DB_USER=$db_user
DB_PASS=$db_pass
DB_PORT=$db_port
EOL
    
    echo "✅ Database credentials updated!"
    
    # Reload variables
    source /var/www/html/todo-app/config/.env
fi

echo ""
echo "Testing database connection..."

# Test connection without database name first
if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ Database server connection successful!"
    
    # Check if database exists
    DB_EXISTS=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES LIKE '$DB_NAME';" 2>/dev/null | grep -o "$DB_NAME")
    
    if [[ "$DB_EXISTS" == "$DB_NAME" ]]; then
        echo "✅ Database '$DB_NAME' already exists."
    else
        echo "Creating database '$DB_NAME'..."
        mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ Database '$DB_NAME' created successfully!"
        else
            echo "❌ Failed to create database '$DB_NAME'"
            echo "Please check if your user has CREATE privileges."
            exit 1
        fi
    fi
    
    # Test connection to the specific database
    if mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" > /dev/null 2>&1; then
        echo "✅ Connection to database '$DB_NAME' successful!"
        echo ""
        echo "🎉 Database setup complete!"
        echo "You can now access your todo application at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'your-ec2-ip')"
        echo ""
    else
        echo "❌ Failed to connect to database '$DB_NAME'"
        echo "Please check your credentials and database permissions."
        exit 1
    fi
else
    echo "❌ Failed to connect to database server."
    echo "Please verify your RDS endpoint, username, and password."
    echo "Also ensure your EC2 security group can connect to RDS on port $DB_PORT"
    exit 1
fi
EOF

chmod +x setup_database.sh

# Create database configuration
echo "Creating database configuration file..."
cat > /var/www/html/todo-app/config/database.php << 'EOF'
<?php
// Load environment variables from .env file
function loadEnv($path) {
    if (!file_exists($path)) {
        return false;
    }
    
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos(trim($line), '#') === 0) {
            continue;
        }
        
        list($name, $value) = explode('=', $line, 2);
        $name = trim($name);
        $value = trim($value);
        
        if (!array_key_exists($name, $_SERVER) && !array_key_exists($name, $_ENV)) {
            putenv(sprintf('%s=%s', $name, $value));
            $_ENV[$name] = $value;
            $_SERVER[$name] = $value;
        }
    }
}

// Load environment variables
loadEnv(__DIR__ . '/.env');

class Database {
    private $host;
    private $db_name;
    private $username;
    private $password;
    private $port;
    public $conn;

    public function __construct() {
        $this->host = getenv('DB_HOST');
        $this->db_name = getenv('DB_NAME');
        $this->username = getenv('DB_USER');
        $this->password = getenv('DB_PASS');
        $this->port = getenv('DB_PORT') ?: '3306';
    }

    public function getConnection() {
        $this->conn = null;
        
        try {
            $dsn = "mysql:host=" . $this->host . ";port=" . $this->port . ";dbname=" . $this->db_name . ";charset=utf8";
            $this->conn = new PDO($dsn, $this->username, $this->password);
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        } catch(PDOException $exception) {
            echo "Connection error: " . $exception->getMessage();
        }
        
        return $this->conn;
    }
}
?>
EOF

# Create Task model
echo "Creating Task model..."
cat > /var/www/html/todo-app/models/Task.php << 'EOF'
<?php
require_once __DIR__ . '/../config/database.php';

class Task {
    private $conn;
    private $table_name = "tasks";

    public $id;
    public $task_name;
    public $deadline_date;
    public $status;
    public $created_at;

    public function __construct() {
        $database = new Database();
        $this->conn = $database->getConnection();
    }

    public function createTable() {
        $query = "CREATE TABLE IF NOT EXISTS " . $this->table_name . " (
            id INT AUTO_INCREMENT PRIMARY KEY,
            task_name VARCHAR(255) NOT NULL,
            deadline_date DATE NOT NULL,
            status ENUM('pending', 'in_progress', 'completed') DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )";
        
        try {
            $this->conn->exec($query);
            return true;
        } catch(PDOException $exception) {
            echo "Table creation error: " . $exception->getMessage();
            return false;
        }
    }

    public function create() {
        $query = "INSERT INTO " . $this->table_name . " 
                  SET task_name=:task_name, deadline_date=:deadline_date, status=:status";

        $stmt = $this->conn->prepare($query);

        $this->task_name = htmlspecialchars(strip_tags($this->task_name));
        $this->deadline_date = htmlspecialchars(strip_tags($this->deadline_date));
        $this->status = htmlspecialchars(strip_tags($this->status));

        $stmt->bindParam(":task_name", $this->task_name);
        $stmt->bindParam(":deadline_date", $this->deadline_date);
        $stmt->bindParam(":status", $this->status);

        if($stmt->execute()) {
            return true;
        }
        return false;
    }

    public function read() {
        $query = "SELECT * FROM " . $this->table_name . " ORDER BY created_at DESC";
        $stmt = $this->conn->prepare($query);
        $stmt->execute();
        return $stmt;
    }

    public function readOne() {
        $query = "SELECT * FROM " . $this->table_name . " WHERE id = ? LIMIT 0,1";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(1, $this->id);
        $stmt->execute();
        
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if($row) {
            $this->task_name = $row['task_name'];
            $this->deadline_date = $row['deadline_date'];
            $this->status = $row['status'];
            $this->created_at = $row['created_at'];
            return true;
        }
        return false;
    }

    public function update() {
        $query = "UPDATE " . $this->table_name . " 
                  SET task_name = :task_name, deadline_date = :deadline_date, status = :status 
                  WHERE id = :id";

        $stmt = $this->conn->prepare($query);

        $this->task_name = htmlspecialchars(strip_tags($this->task_name));
        $this->deadline_date = htmlspecialchars(strip_tags($this->deadline_date));
        $this->status = htmlspecialchars(strip_tags($this->status));
        $this->id = htmlspecialchars(strip_tags($this->id));

        $stmt->bindParam(':task_name', $this->task_name);
        $stmt->bindParam(':deadline_date', $this->deadline_date);
        $stmt->bindParam(':status', $this->status);
        $stmt->bindParam(':id', $this->id);

        if($stmt->execute()) {
            return true;
        }
        return false;
    }

    public function delete() {
        $query = "DELETE FROM " . $this->table_name . " WHERE id = ?";
        $stmt = $this->conn->prepare($query);
        
        $this->id = htmlspecialchars(strip_tags($this->id));
        $stmt->bindParam(1, $this->id);

        if($stmt->execute()) {
            return true;
        }
        return false;
    }
}
?>
EOF

# Create main application file
echo "Creating main application file..."
cat > /var/www/html/todo-app/index.php << 'EOF'
<?php
require_once 'models/Task.php';

$task = new Task();
$task->createTable(); // Create table if it doesn't exist

// Handle form submissions
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    if (isset($_POST['action'])) {
        switch ($_POST['action']) {
            case 'create':
                $task->task_name = $_POST['task_name'];
                $task->deadline_date = $_POST['deadline_date'];
                $task->status = $_POST['status'];
                if ($task->create()) {
                    $message = "Task created successfully!";
                } else {
                    $error = "Unable to create task.";
                }
                break;
                
            case 'update':
                $task->id = $_POST['id'];
                $task->task_name = $_POST['task_name'];
                $task->deadline_date = $_POST['deadline_date'];
                $task->status = $_POST['status'];
                if ($task->update()) {
                    $message = "Task updated successfully!";
                } else {
                    $error = "Unable to update task.";
                }
                break;
                
            case 'delete':
                $task->id = $_POST['id'];
                if ($task->delete()) {
                    $message = "Task deleted successfully!";
                } else {
                    $error = "Unable to delete task.";
                }
                break;
        }
    }
}

// Get all tasks
$stmt = $task->read();
$tasks = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Get task for editing
$editTask = null;
if (isset($_GET['edit'])) {
    $editTaskObj = new Task();
    $editTaskObj->id = $_GET['edit'];
    if ($editTaskObj->readOne()) {
        $editTask = $editTaskObj;
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Todo Application</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
            margin-bottom: 30px;
        }
        .form-group {
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
            color: #555;
        }
        input, select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 16px;
        }
        button {
            background-color: #007bff;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
            margin-right: 10px;
        }
        button:hover {
            background-color: #0056b3;
        }
        .btn-danger {
            background-color: #dc3545;
        }
        .btn-danger:hover {
            background-color: #c82333;
        }
        .btn-warning {
            background-color: #ffc107;
            color: #212529;
        }
        .btn-warning:hover {
            background-color: #e0a800;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 30px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        .status-pending {
            color: #ffc107;
            font-weight: bold;
        }
        .status-in_progress {
            color: #17a2b8;
            font-weight: bold;
        }
        .status-completed {
            color: #28a745;
            font-weight: bold;
        }
        .message {
            background-color: #d4edda;
            color: #155724;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .error {
            background-color: #f8d7da;
            color: #721c24;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .form-section {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 30px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Todo Application</h1>
        
        <?php if (isset($message)): ?>
            <div class="message"><?php echo $message; ?></div>
        <?php endif; ?>
        
        <?php if (isset($error)): ?>
            <div class="error"><?php echo $error; ?></div>
        <?php endif; ?>
        
        <div class="form-section">
            <h2><?php echo $editTask ? 'Edit Task' : 'Add New Task'; ?></h2>
            <form method="POST">
                <input type="hidden" name="action" value="<?php echo $editTask ? 'update' : 'create'; ?>">
                <?php if ($editTask): ?>
                    <input type="hidden" name="id" value="<?php echo $editTask->id; ?>">
                <?php endif; ?>
                
                <div class="form-group">
                    <label for="task_name">Task Name:</label>
                    <input type="text" id="task_name" name="task_name" required 
                           value="<?php echo $editTask ? htmlspecialchars($editTask->task_name) : ''; ?>">
                </div>
                
                <div class="form-group">
                    <label for="deadline_date">Deadline Date:</label>
                    <input type="date" id="deadline_date" name="deadline_date" required 
                           value="<?php echo $editTask ? $editTask->deadline_date : ''; ?>">
                </div>
                
                <div class="form-group">
                    <label for="status">Status:</label>
                    <select id="status" name="status" required>
                        <option value="pending" <?php echo ($editTask && $editTask->status == 'pending') ? 'selected' : ''; ?>>Pending</option>
                        <option value="in_progress" <?php echo ($editTask && $editTask->status == 'in_progress') ? 'selected' : ''; ?>>In Progress</option>
                        <option value="completed" <?php echo ($editTask && $editTask->status == 'completed') ? 'selected' : ''; ?>>Completed</option>
                    </select>
                </div>
                
                <button type="submit"><?php echo $editTask ? 'Update Task' : 'Add Task'; ?></button>
                <?php if ($editTask): ?>
                    <a href="index.php"><button type="button" class="btn-warning">Cancel</button></a>
                <?php endif; ?>
            </form>
        </div>
        
        <h2>Tasks List</h2>
        <?php if (count($tasks) > 0): ?>
            <table>
                <thead>
                    <tr>
                        <th>Task Name</th>
                        <th>Deadline</th>
                        <th>Status</th>
                        <th>Created At</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($tasks as $taskItem): ?>
                        <tr>
                            <td><?php echo htmlspecialchars($taskItem['task_name']); ?></td>
                            <td><?php echo date('M d, Y', strtotime($taskItem['deadline_date'])); ?></td>
                            <td class="status-<?php echo $taskItem['status']; ?>">
                                <?php echo ucfirst(str_replace('_', ' ', $taskItem['status'])); ?>
                            </td>
                            <td><?php echo date('M d, Y H:i', strtotime($taskItem['created_at'])); ?></td>
                            <td>
                                <a href="?edit=<?php echo $taskItem['id']; ?>">
                                    <button type="button" class="btn-warning">Edit</button>
                                </a>
                                <form method="POST" style="display: inline;">
                                    <input type="hidden" name="action" value="delete">
                                    <input type="hidden" name="id" value="<?php echo $taskItem['id']; ?>">
                                    <button type="submit" class="btn-danger" 
                                            onclick="return confirm('Are you sure you want to delete this task?')">
                                        Delete
                                    </button>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php else: ?>
            <p>No tasks found. Add your first task above!</p>
        <?php endif; ?>
    </div>
</body>
</html>
EOF

# Set proper permissions
echo "Setting file permissions..."
sudo chown -R www-data:www-data /var/www/html/todo-app
sudo chmod -R 755 /var/www/html/todo-app

# Create Apache virtual host
echo "Configuring Apache virtual host..."
sudo tee /etc/apache2/sites-available/todo-app.conf > /dev/null << EOF
<VirtualHost *:80>
    DocumentRoot /var/www/html/todo-app
    
    <Directory /var/www/html/todo-app>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/todo-app_error.log
    CustomLog \${APACHE_LOG_DIR}/todo-app_access.log combined
</VirtualHost>
EOF

# Disable default site and enable todo-app
sudo a2dissite 000-default
sudo a2ensite todo-app
sudo a2enmod rewrite

# Restart Apache
echo "Restarting Apache..."
sudo systemctl restart apache2

# Attempt database setup
create_database

# Display completion message
echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "Your Todo application is now ready!"
echo ""
echo "📝 Database Setup:"
echo "If database creation failed or you need to configure it later:"
echo "   ./setup_database.sh"
echo ""
echo "🌐 Access your application at:http://<your-ec2-public-ip>"
echo ""
echo "🔒 Security Group Requirements:"
echo "   - EC2: Allow HTTP (port 80) inbound from 0.0.0.0/0"
echo "   - RDS: Allow MySQL (port 3306) from EC2 security group"
echo ""
echo "📁 Application files located at: /var/www/html/todo-app/"
echo ""
echo "🔧 Useful commands:"
echo "   - Setup database: ./setup_database.sh"
echo "   - Restart Apache: sudo systemctl restart apache2"
echo "   - View Apache logs: sudo tail -f /var/log/apache2/todo-app_error.log"
echo "   - Edit config: nano /var/www/html/todo-app/config/.env"
echo ""
echo "========================================="
