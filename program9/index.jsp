<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Java Todo Application</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        h1 {
            color: #333;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.1);
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: bold;
            color: #555;
            font-size: 1.1em;
        }
        input, select {
            width: 100%;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s ease;
            box-sizing: border-box;
        }
        input:focus, select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 10px rgba(102, 126, 234, 0.3);
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 25px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            margin-right: 10px;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        .btn-danger {
            background: linear-gradient(135deg, #ff6b6b 0%, #ee5a52 100%);
        }
        .btn-warning {
            background: linear-gradient(135deg, #feca57 0%, #ff9ff3 100%);
            color: #333;
        }
        .btn-success {
            background: linear-gradient(135deg, #48cae4 0%, #023e8a 100%);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 30px;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        th, td {
            padding: 15px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        th {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            font-weight: bold;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        tr:hover {
            background-color: #f8f9ff;
            transition: background-color 0.3s ease;
        }
        .status-PENDING {
            color: #ffa726;
            font-weight: bold;
            background-color: #fff3e0;
            padding: 5px 10px;
            border-radius: 20px;
            display: inline-block;
        }
        .status-IN_PROGRESS {
            color: #29b6f6;
            font-weight: bold;
            background-color: #e3f2fd;
            padding: 5px 10px;
            border-radius: 20px;
            display: inline-block;
        }
        .status-COMPLETED {
            color: #66bb6a;
            font-weight: bold;
            background-color: #e8f5e8;
            padding: 5px 10px;
            border-radius: 20px;
            display: inline-block;
        }
        .message {
            background: linear-gradient(135deg, #d4edda 0%, #c3e6cb 100%);
            color: #155724;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            border-left: 5px solid #28a745;
            animation: slideIn 0.5s ease;
        }
        .error {
            background: linear-gradient(135deg, #f8d7da 0%, #f5c6cb 100%);
            color: #721c24;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            border-left: 5px solid #dc3545;
            animation: slideIn 0.5s ease;
        }
        .form-section {
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 30px;
            border: 2px solid #dee2e6;
        }
        .form-section h2 {
            color: #495057;
            margin-bottom: 20px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateY(-20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        .no-tasks {
            text-align: center;
            color: #6c757d;
            font-style: italic;
            font-size: 1.2em;
            padding: 40px;
            background-color: #f8f9fa;
            border-radius: 10px;
            border: 2px dashed #dee2e6;
        }
        .action-buttons {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        .deadline-warning {
            color: #dc3545;
            font-weight: bold;
        }
        .deadline-today {
            color: #ffc107;
            font-weight: bold;
        }
        .deadline-future {
            color: #28a745;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>☕ Java Todo Application</h1>
        
        <c:if test="${not empty message}">
            <div class="message">${message}</div>
        </c:if>
        
        <c:if test="${not empty error}">
            <div class="error">${error}</div>
        </c:if>
        
        <div class="form-section">
            <h2>
                <c:choose>
                    <c:when test="${not empty editTask}">
                        ✏️ Edit Task
                    </c:when>
                    <c:otherwise>
                        ➕ Add New Task
                    </c:otherwise>
                </c:choose>
            </h2>
            
            <form method="POST" action="tasks">
                <input type="hidden" name="action" value="${not empty editTask ? 'update' : 'create'}">
                <c:if test="${not empty editTask}">
                    <input type="hidden" name="id" value="${editTask.id}">
                </c:if>
                
                <div class="form-group">
                    <label for="taskName">📝 Task Name:</label>
                    <input type="text" id="taskName" name="taskName" required 
                           value="${not empty editTask ? editTask.taskName : ''}"
                           placeholder="Enter your task description...">
                </div>
                
                <div class="form-group">
                    <label for="deadlineDate">📅 Deadline Date:</label>
                    <input type="date" id="deadlineDate" name="deadlineDate" required 
                           value="${not empty editTask ? editTask.deadlineDate : ''}">
                </div>
                
                <div class="form-group">
                    <label for="status">🏷️ Status:</label>
                    <select id="status" name="status" required>
                        <option value="PENDING" ${(not empty editTask && editTask.status == 'PENDING') ? 'selected' : ''}>
                            ⏳ Pending
                        </option>
                        <option value="IN_PROGRESS" ${(not empty editTask && editTask.status == 'IN_PROGRESS') ? 'selected' : ''}>
                            🔄 In Progress
                        </option>
                        <option value="COMPLETED" ${(not empty editTask && editTask.status == 'COMPLETED') ? 'selected' : ''}>
                            ✅ Completed
                        </option>
                    </select>
                </div>
                
                <div class="action-buttons">
                    <button type="submit" class="btn-success">
                        ${not empty editTask ? '💾 Update Task' : '➕ Add Task'}
                    </button>
                    <c:if test="${not empty editTask}">
                        <a href="tasks">
                            <button type="button" class="btn-warning">❌ Cancel</button>
                        </a>
                    </c:if>
                </div>
            </form>
        </div>
        
        <h2>📋 Tasks List</h2>
        
        <c:choose>
            <c:when test="${not empty tasks}">
                <table>
                    <thead>
                        <tr>
                            <th>📝 Task Name</th>
                            <th>📅 Deadline</th>
                            <th>🏷️ Status</th>
                            <th>🕒 Created At</th>
                            <th>⚙️ Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <c:forEach var="task" items="${tasks}">
                            <tr>
                                <td>
                                    <strong>${task.taskName}</strong>
                                </td>
                                <td>
                                    <jsp:useBean id="now" class="java.util.Date" />
                                    <fmt:parseDate value="${task.deadlineDate}" pattern="yyyy-MM-dd" var="deadline" />
                                    <fmt:formatDate value="${deadline}" pattern="MMM dd, yyyy" var="formattedDeadline" />
                                    
                                    <c:choose>
                                        <c:when test="${deadline.time < now.time}">
                                            <span class="deadline-warning">⚠️ ${formattedDeadline}</span>
                                        </c:when>
                                        <c:when test="${deadline.time == now.time}">
                                            <span class="deadline-today">📅 ${formattedDeadline}</span>
                                        </c:when>
                                        <c:otherwise>
                                            <span class="deadline-future">📅 ${formattedDeadline}</span>
                                        </c:otherwise>
                                    </c:choose>
                                </td>
                                <td>
                                    <span class="status-${task.status}">
                                        <c:choose>
                                            <c:when test="${task.status == 'PENDING'}">⏳ Pending</c:when>
                                            <c:when test="${task.status == 'IN_PROGRESS'}">🔄 In Progress</c:when>
                                            <c:when test="${task.status == 'COMPLETED'}">✅ Completed</c:when>
                                        </c:choose>
                                    </span>
                                </td>
                                <td>
                                    <fmt:formatDate value="${task.createdAt}" pattern="MMM dd, yyyy HH:mm" />
                                </td>
                                <td>
                                    <div class="action-buttons">
                                        <a href="tasks?action=edit&id=${task.id}">
                                            <button type="button" class="btn-warning">✏️ Edit</button>
                                        </a>
                                        <form method="POST" action="tasks" style="display: inline;">
                                            <input type="hidden" name="action" value="delete">
                                            <input type="hidden" name="id" value="${task.id}">
                                            <button type="submit" class="btn-danger" 
                                                    onclick="return confirm('Are you sure you want to delete this task?')">
                                                🗑️ Delete
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        </c:forEach>
                    </tbody>
                </table>
            </c:when>
            <c:otherwise>
                <div class="no-tasks">
                    <h3>📋 No tasks found!</h3>
                    <p>Add your first task using the form above to get started.</p>
                </div>
            </c:otherwise>
        </c:choose>
    </div>

    <script>
        // Auto-hide messages after 5 seconds
        setTimeout(function() {
            const messages = document.querySelectorAll('.message, .error');
            messages.forEach(function(msg) {
                msg.style.opacity = '0';
                msg.style.transform = 'translateY(-20px)';
                setTimeout(function() {
                    msg.remove();
                }, 500);
            });
        }, 5000);

        // Set minimum date to today for deadline input
        document.getElementById('deadlineDate').min = new Date().toISOString().split('T')[0];
    </script>
</body>
</html>