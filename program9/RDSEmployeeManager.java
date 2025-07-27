import java.sql.*;
import java.util.Scanner;

public class RDSEmployeeManager {
    // Database connection parameters - UPDATE THESE WITH YOUR RDS DETAILS
    static final String JDBC_URL = "jdbc:mysql://your-rds-endpoint.region.rds.amazonaws.com:3306/your_database_name";
    static final String JDBC_USER = "your_master_username";
    static final String JDBC_PASS = "your_master_password";
    
    public static void main(String[] args) {
        Connection conn = null;
        Scanner scanner = new Scanner(System.in);
        
        try {
            // 1. Load the JDBC driver
            Class.forName("com.mysql.cj.jdbc.Driver");
            
            // 2. Establish the connection
            System.out.println("Connecting to RDS MySQL database...");
            conn = DriverManager.getConnection(JDBC_URL, JDBC_USER, JDBC_PASS);
            System.out.println("Connected successfully to RDS!");
            
            // 3. Create employees table if it doesn't exist
            createEmployeeTable(conn);
            
            // 4. Get employee name from user input
            System.out.print("Enter employee name to insert: ");
            String employeeName = scanner.nextLine();
            
            System.out.print("Enter employee email: ");
            String employeeEmail = scanner.nextLine();
            
            System.out.print("Enter employee country: ");
            String employeeCountry = scanner.nextLine();
            
            System.out.print("Enter employee salary: ");
            double employeeSalary = scanner.nextDouble();
            
            // 5. Insert the employee
            insertEmployee(conn, employeeName, employeeEmail, employeeCountry, employeeSalary);
            
            // 6. Display all employees
            displayAllEmployees(conn);
            
        } catch (ClassNotFoundException e) {
            System.err.println("MySQL JDBC Driver not found!");
            System.err.println("Make sure mysql-connector-java.jar is in your classpath");
            e.printStackTrace();
        } catch (SQLException e) {
            System.err.println("Database connection error!");
            System.err.println("Check your RDS endpoint, credentials, and security groups");
            e.printStackTrace();
        } catch (Exception e) {
            System.err.println("Unexpected error occurred!");
            e.printStackTrace();
        } finally {
            // Close the connection
            try {
                if (conn != null && !conn.isClosed()) {
                    conn.close();
                    System.out.println("Database connection closed.");
                }
                scanner.close();
            } catch (SQLException e) {
                e.printStackTrace();
            }
        }
    }
    
    /**
     * Creates the employees table if it doesn't exist
     */
    private static void createEmployeeTable(Connection conn) throws SQLException {
        String createTableSql = """
            CREATE TABLE IF NOT EXISTS employees (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                email VARCHAR(150) UNIQUE NOT NULL,
                country VARCHAR(50),
                salary DECIMAL(10, 2),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """;
        
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(createTableSql);
            System.out.println("Employee table created or already exists.");
        }
    }
    
    /**
     * Inserts a new employee into the database
     */
    private static void insertEmployee(Connection conn, String name, String email, 
                                     String country, double salary) throws SQLException {
        String insertSql = "INSERT INTO employees (name, email, country, salary) VALUES (?, ?, ?, ?)";
        
        try (PreparedStatement pstmt = conn.prepareStatement(insertSql)) {
            pstmt.setString(1, name);
            pstmt.setString(2, email);
            pstmt.setString(3, country);
            pstmt.setDouble(4, salary);
            
            int rowsAffected = pstmt.executeUpdate();
            if (rowsAffected > 0) {
                System.out.println("Employee '" + name + "' inserted successfully!");
            }
        } catch (SQLException e) {
            if (e.getErrorCode() == 1062) { // Duplicate entry error
                System.err.println("Error: Employee with email '" + email + "' already exists!");
            } else {
                throw e;
            }
        }
    }
    
    /**
     * Displays all employees from the database
     */
    private static void displayAllEmployees(Connection conn) throws SQLException {
        String selectSql = "SELECT * FROM employees ORDER BY id";
        
        try (Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(selectSql)) {
            
            System.out.println("\n" + "=".repeat(80));
            System.out.println("EMPLOYEES TABLE");
            System.out.println("=".repeat(80));
            System.out.printf("%-5s %-20s %-30s %-15s %-12s %-20s%n", 
                            "ID", "NAME", "EMAIL", "COUNTRY", "SALARY", "CREATED_AT");
            System.out.println("-".repeat(80));
            
            boolean hasRecords = false;
            while (rs.next()) {
                hasRecords = true;
                System.out.printf("%-5d %-20s %-30s %-15s $%-11.2f %-20s%n",
                    rs.getInt("id"),
                    rs.getString("name"),
                    rs.getString("email"),
                    rs.getString("country"),
                    rs.getDouble("salary"),
                    rs.getTimestamp("created_at")
                );
            }
            
            if (!hasRecords) {
                System.out.println("No employees found in the database.");
            }
            System.out.println("=".repeat(80));
        }
    }
}