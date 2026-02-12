<?php
/**
 * Standalone PHP API for Getting a Single Chat Connection
 * 
 * This API endpoint can be used by mobile apps to get a specific chat connection
 * between two chat users without going through CodeIgniter's routing system.
 * 
 * Usage:
 * POST /mobile_apis/get_connection.php
 * 
 * Request body (JSON or form-data):
 * {
 *   "chat_user_one": 123,
 *   "chat_user_two": 456
 * }
 * 
 * OR using user IDs:
 * {
 *   "user_one_id": 123,
 *   "user_one_type": "staff",
 *   "user_two_id": 456,
 *   "user_two_type": "student"
 * }
 * 
 * Response:
 * {
 *   "action": "connection",
 *   "status": "success",
 *   "connection": {...} or null
 * }
 */

// Set CORS headers for mobile app access
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Max-Age: 86400');
header('Content-Type: application/json');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Allow both GET and POST requests
if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'POST'])) {
    http_response_code(405);
    echo json_encode([
        'action' => 'error',
        'status' => 'error',
        'message' => 'Method not allowed. Use GET or POST.'
    ]);
    exit;
}

// Define CodeIgniter constants to avoid "No direct script access allowed" errors
if (!defined('BASEPATH')) {
    define('BASEPATH', __DIR__ . '/../system/');
}
if (!defined('ENVIRONMENT')) {
    define('ENVIRONMENT', 'production');
}

// Enable error logging for debugging (disable in production)
error_reporting(E_ALL);
ini_set('display_errors', 0); // Don't display errors to client
ini_set('log_errors', 1);

/**
 * Get database connection
 */
function getDbConnection()
{
    // Create database connection
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );

    if ($mysqli->connect_error) {
        error_log("Database connection failed: " . $mysqli->connect_error);
        return null;
    }

    return $mysqli;
}

/**
 * Get chat_user_id from staff_id or student_id
 */
function getChatUserId($user_id, $user_type = 'staff')
{
    $mysqli = getDbConnection();
    if (!$mysqli) {
        error_log("getChatUserId: Failed to get database connection");
        return null;
    }

    $user_id = $mysqli->real_escape_string($user_id);
    $user_type = $mysqli->real_escape_string($user_type);

    if ($user_type == 'staff') {
        $sql = "SELECT id FROM fl_chat_users WHERE staff_id = '$user_id' AND user_type = 'staff' LIMIT 1";
    } else {
        $sql = "SELECT id FROM fl_chat_users WHERE student_id = '$user_id' AND user_type = 'student' LIMIT 1";
    }

    $result = $mysqli->query($sql);
    if ($result && $row = $result->fetch_assoc()) {
        $chat_user_id = intval($row['id']);
        $mysqli->close();
        return $chat_user_id;
    }
    
    if ($mysqli->error) {
        error_log("getChatUserId SQL error: " . $mysqli->error);
    }

    $mysqli->close();
    return null;
}

/**
 * Get connection details between two chat_user_ids
 */
function getConnectionBetweenUsers($chat_user_one_id, $chat_user_two_id)
{
    $mysqli = getDbConnection();
    if (!$mysqli) {
        error_log("getConnectionBetweenUsers: Failed to get database connection");
        return null;
    }

    $chat_user_one_id = $mysqli->real_escape_string($chat_user_one_id);
    $chat_user_two_id = $mysqli->real_escape_string($chat_user_two_id);

    // Check both directions (user_one-user_two and user_two-user_one)
    $sql = "SELECT 
                cc.id,
                cc.chat_user_one,
                cc.chat_user_two,
                cc.created_at,
                cc.updated_at,
                cu1.staff_id as user_one_staff_id,
                cu1.student_id as user_one_student_id,
                cu1.user_type as user_one_type,
                cu2.staff_id as user_two_staff_id,
                cu2.student_id as user_two_student_id,
                cu2.user_type as user_two_type
            FROM fl_chat_connections cc
            LEFT JOIN fl_chat_users cu1 ON cc.chat_user_one = cu1.id
            LEFT JOIN fl_chat_users cu2 ON cc.chat_user_two = cu2.id
            WHERE (cc.chat_user_one = '$chat_user_one_id' AND cc.chat_user_two = '$chat_user_two_id')
               OR (cc.chat_user_one = '$chat_user_two_id' AND cc.chat_user_two = '$chat_user_one_id')
            LIMIT 1";
    
    $result = $mysqli->query($sql);
    if ($result && $row = $result->fetch_assoc()) {
        $connection = [
            'id' => $row['id'],
            'chat_user_one' => $row['chat_user_one'],
            'chat_user_two' => $row['chat_user_two'],
            'chat_user_one_id' => $row['chat_user_one'],
            'chat_user_two_id' => $row['chat_user_two'],
            'user_one_id' => $row['user_one_staff_id'] ?: $row['user_one_student_id'],
            'user_one_type' => $row['user_one_type'],
            'user_two_id' => $row['user_two_staff_id'] ?: $row['user_two_student_id'],
            'user_two_type' => $row['user_two_type'],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at']
        ];
        $mysqli->close();
        return $connection;
    }

    if ($mysqli->error) {
        error_log("getConnectionBetweenUsers SQL error: " . $mysqli->error);
    }

    $mysqli->close();
    return null;
}

// Main API logic
try {
    // Get input data (support both JSON and form-data, GET and POST)
    $input = json_decode(file_get_contents('php://input'), true);
    if ($input) {
        $chat_user_one = isset($input['chat_user_one']) ? $input['chat_user_one'] : null;
        $chat_user_two = isset($input['chat_user_two']) ? $input['chat_user_two'] : null;
        $user_one_id = isset($input['user_one_id']) ? $input['user_one_id'] : null;
        $user_one_type = isset($input['user_one_type']) ? trim($input['user_one_type']) : 'staff';
        $user_two_id = isset($input['user_two_id']) ? $input['user_two_id'] : null;
        $user_two_type = isset($input['user_two_type']) ? trim($input['user_two_type']) : 'student';
    } else {
        $chat_user_one = isset($_POST['chat_user_one']) ? $_POST['chat_user_one'] : (isset($_GET['chat_user_one']) ? $_GET['chat_user_one'] : null);
        $chat_user_two = isset($_POST['chat_user_two']) ? $_POST['chat_user_two'] : (isset($_GET['chat_user_two']) ? $_GET['chat_user_two'] : null);
        $user_one_id = isset($_POST['user_one_id']) ? $_POST['user_one_id'] : (isset($_GET['user_one_id']) ? $_GET['user_one_id'] : null);
        $user_one_type = isset($_POST['user_one_type']) ? trim($_POST['user_one_type']) : (isset($_GET['user_one_type']) ? trim($_GET['user_one_type']) : 'staff');
        $user_two_id = isset($_POST['user_two_id']) ? $_POST['user_two_id'] : (isset($_GET['user_two_id']) ? $_GET['user_two_id'] : null);
        $user_two_type = isset($_POST['user_two_type']) ? trim($_POST['user_two_type']) : (isset($_GET['user_two_type']) ? trim($_GET['user_two_type']) : 'student');
    }

    // Determine chat_user_one and chat_user_two
    // If chat_user_one and chat_user_two are provided directly, use them
    // Otherwise, convert user_one_id/user_two_id to chat_user_ids (allow 0 for Support)
    if ($chat_user_one === null || $chat_user_two === null) {
        // Need to convert user IDs to chat_user_ids (user_id can be 0 for Support)
        $missing = ($user_one_id === null || $user_one_id === '') || ($user_two_id === null || $user_two_id === '');
        if ($missing) {
            http_response_code(400);
            echo json_encode([
                'action' => 'error',
                'status' => 'error',
                'message' => 'Missing required fields. Provide either (chat_user_one, chat_user_two) or (user_one_id, user_one_type, user_two_id, user_two_type)'
            ]);
            exit;
        }

        // Validate user types
        $user_one_type = strtolower($user_one_type);
        $user_two_type = strtolower($user_two_type);
        
        if (!in_array($user_one_type, ['staff', 'student']) || !in_array($user_two_type, ['staff', 'student'])) {
            http_response_code(400);
            echo json_encode([
                'action' => 'error',
                'status' => 'error',
                'message' => 'Invalid user_type. Must be "staff" or "student"'
            ]);
            exit;
        }

        // Get chat_user_ids (pass string so Support user_id 0 works)
        $chat_user_one = getChatUserId((string) $user_one_id, $user_one_type);
        $chat_user_two = getChatUserId((string) $user_two_id, $user_two_type);

        if (!$chat_user_one) {
            http_response_code(404);
            echo json_encode([
                'action' => 'error',
                'status' => 'error',
                'message' => 'Chat user not found for user_one_id: ' . $user_one_id
            ]);
            exit;
        }

        if (!$chat_user_two) {
            http_response_code(404);
            echo json_encode([
                'action' => 'error',
                'status' => 'error',
                'message' => 'Chat user not found for user_two_id: ' . $user_two_id
            ]);
            exit;
        }
    } else {
        // Validate chat_user_one and chat_user_two are integers
        $chat_user_one = intval($chat_user_one);
        $chat_user_two = intval($chat_user_two);

        if ($chat_user_one <= 0 || $chat_user_two <= 0) {
            http_response_code(400);
            echo json_encode([
                'action' => 'error',
                'status' => 'error',
                'message' => 'Invalid chat_user_one or chat_user_two. Must be positive integers.'
            ]);
            exit;
        }
    }

    // Get connection between the two chat users
    $connection = getConnectionBetweenUsers($chat_user_one, $chat_user_two);

    // Return success response (connection may be null if not found); connection_id for Flutter repository
    http_response_code(200);
    echo json_encode([
        'action' => 'connection',
        'status' => 'success',
        'success' => true,
        'connection' => $connection,
        'exists' => $connection !== null,
        'connection_id' => $connection !== null ? (string) $connection['id'] : null
    ]);

} catch (Exception $e) {
    // Log the full error for debugging
    error_log("API Error in get_connection.php: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    
    http_response_code(500);
    echo json_encode([
        'action' => 'error',
        'status' => 'error',
        'message' => 'Internal server error: ' . $e->getMessage(),
        'file' => basename($e->getFile()),
        'line' => $e->getLine()
    ]);
}
