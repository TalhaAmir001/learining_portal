<?php
/**
 * Standalone PHP API for Creating Chat Connections
 * 
 * This API endpoint can be used by mobile apps to create chat connections
 * between two users without going through CodeIgniter's routing system.
 * 
 * It does the same job as the create_connection action in websocket_server.php
 * 
 * Usage:
 * POST /mobile_apis/create_connection.php
 * 
 * Request body (JSON or form-data):
 * {
 *   "user_one_id": 123,
 *   "user_one_type": "staff",
 *   "user_two_id": 456,
 *   "user_two_type": "student"
 * }
 * 
 * Response:
 * {
 *   "action": "connection_created",
 *   "status": "success",
 *   "connection_id": 789,
 *   "is_new": true/false
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

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'action' => 'error',
        'status' => 'error',
        'message' => 'Method not allowed. Use POST.'
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
 * Create a new chat user entry in fl_chat_users table
 */
function createChatUser($user_id, $user_type = 'staff')
{
    $mysqli = getDbConnection();
    if (!$mysqli) {
        error_log("createChatUser: Failed to get database connection");
        return null;
    }

    $user_id = $mysqli->real_escape_string($user_id);
    $user_type = $mysqli->real_escape_string($user_type);

    // Insert based on user type
    if ($user_type == 'staff') {
        $sql = "INSERT INTO fl_chat_users (staff_id, user_type, created_at, updated_at)
                VALUES ('$user_id', 'staff', NOW(), NOW())
                ON DUPLICATE KEY UPDATE updated_at = NOW()";
    } else {
        $sql = "INSERT INTO fl_chat_users (student_id, user_type, created_at, updated_at)
                VALUES ('$user_id', 'student', NOW(), NOW())
                ON DUPLICATE KEY UPDATE updated_at = NOW()";
    }

    if ($mysqli->query($sql)) {
        // Get the chat_user_id (either newly inserted or existing)
        $chat_user_id = getChatUserId($user_id, $user_type);
        $mysqli->close();
        return $chat_user_id;
    } else {
        error_log("createChatUser SQL error: " . $mysqli->error);
        error_log("SQL query: " . $sql);
    }

    $mysqli->close();
    return null;
}

/**
 * Verify that a chat_user_id exists in the database
 */
function verifyChatUserExists($chat_user_id)
{
    $mysqli = getDbConnection();
    if (!$mysqli) {
        return false;
    }

    $chat_user_id = $mysqli->real_escape_string($chat_user_id);
    $sql = "SELECT id FROM fl_chat_users WHERE id = '$chat_user_id' LIMIT 1";
    $result = $mysqli->query($sql);
    
    $exists = ($result && $result->num_rows > 0);
    $mysqli->close();
    return $exists;
}

/**
 * Get connection ID between two chat_user_ids (if exists)
 */
function getConnectionBetweenUsers($chat_user_one_id, $chat_user_two_id)
{
    $mysqli = getDbConnection();
    if (!$mysqli) {
        return null;
    }

    $chat_user_one_id = $mysqli->real_escape_string($chat_user_one_id);
    $chat_user_two_id = $mysqli->real_escape_string($chat_user_two_id);

    // Check both directions (user_one-user_two and user_two-user_one)
    $sql = "SELECT id FROM fl_chat_connections 
            WHERE (chat_user_one = '$chat_user_one_id' AND chat_user_two = '$chat_user_two_id')
               OR (chat_user_one = '$chat_user_two_id' AND chat_user_two = '$chat_user_one_id')
            LIMIT 1";
    
    $result = $mysqli->query($sql);
    if ($result && $row = $result->fetch_assoc()) {
        $connection_id = $row['id'];
        $mysqli->close();
        return $connection_id;
    }

    $mysqli->close();
    return null;
}

/**
 * Create a new chat connection between two chat_user_ids
 */
function createChatConnection($chat_user_one_id, $chat_user_two_id)
{
    $mysqli = getDbConnection();
    if (!$mysqli) {
        error_log("createChatConnection: Database connection failed");
        return null;
    }

    // Ensure values are integers
    $chat_user_one_id = intval($chat_user_one_id);
    $chat_user_two_id = intval($chat_user_two_id);

    if ($chat_user_one_id <= 0 || $chat_user_two_id <= 0) {
        error_log("createChatConnection: Invalid chat_user_id values: one={$chat_user_one_id}, two={$chat_user_two_id}");
        $mysqli->close();
        return null;
    }

    // Verify both users exist before attempting insert
    if (!verifyChatUserExists($chat_user_one_id)) {
        error_log("createChatConnection: chat_user_one_id {$chat_user_one_id} does not exist");
        $mysqli->close();
        return null;
    }

    if (!verifyChatUserExists($chat_user_two_id)) {
        error_log("createChatConnection: chat_user_two_id {$chat_user_two_id} does not exist");
        $mysqli->close();
        return null;
    }

    $sql = "INSERT INTO fl_chat_connections (chat_user_one, chat_user_two, created_at, updated_at)
            VALUES ($chat_user_one_id, $chat_user_two_id, NOW(), NOW())";

    if ($mysqli->query($sql)) {
        $connection_id = $mysqli->insert_id;
        $mysqli->close();
        return $connection_id;
    }

    $error = $mysqli->error;
    $errno = $mysqli->errno;
    error_log("createChatConnection SQL Error ({$errno}): {$error}");
    error_log("Attempted to insert: chat_user_one={$chat_user_one_id}, chat_user_two={$chat_user_two_id}");
    $mysqli->close();
    return null;
}

// Main API logic
try {
    // Get POST data (support both JSON and form-data)
    $input = json_decode(file_get_contents('php://input'), true);
    if ($input) {
        $user_one_id = isset($input['user_one_id']) ? $input['user_one_id'] : null;
        $user_one_type = isset($input['user_one_type']) ? trim($input['user_one_type']) : 'staff';
        $user_two_id = isset($input['user_two_id']) ? $input['user_two_id'] : null;
        $user_two_type = isset($input['user_two_type']) ? trim($input['user_two_type']) : 'student';
    } else {
        $user_one_id = isset($_POST['user_one_id']) ? $_POST['user_one_id'] : null;
        $user_one_type = isset($_POST['user_one_type']) ? trim($_POST['user_one_type']) : 'staff';
        $user_two_id = isset($_POST['user_two_id']) ? $_POST['user_two_id'] : null;
        $user_two_type = isset($_POST['user_two_type']) ? trim($_POST['user_two_type']) : 'student';
    }

    // Validate required fields (allow 0 for Support user)
    $missing = ($user_one_id === null || $user_one_id === '') || ($user_two_id === null || $user_two_id === '');
    if ($missing) {
        http_response_code(400);
        echo json_encode([
            'action' => 'error',
            'status' => 'error',
            'message' => 'Missing user_one_id or user_two_id'
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

    // Ensure both users exist in fl_chat_users (user_id can be 0 for Support)
    $chat_user_one_id = getChatUserId((string) $user_one_id, $user_one_type);
    if (!$chat_user_one_id) {
        // Try to create it (Support user_id 0 must exist – run add_support_chat_user.sql)
        $chat_user_one_id = createChatUser((string) $user_one_id, $user_one_type);
        if (!$chat_user_one_id) {
            http_response_code(500);
            echo json_encode([
                'action' => 'error',
                'status' => 'error',
                'message' => 'Failed to get or create chat user for user_one_id: ' . $user_one_id
            ]);
            exit;
        }
    }

    $chat_user_two_id = getChatUserId((string) $user_two_id, $user_two_type);
    if (!$chat_user_two_id) {
        // Try to create it (Support user_id 0 must exist – run add_support_chat_user.sql)
        $chat_user_two_id = createChatUser((string) $user_two_id, $user_two_type);
        if (!$chat_user_two_id) {
            http_response_code(500);
            echo json_encode([
                'action' => 'error',
                'status' => 'error',
                'message' => 'Failed to get or create chat user for user_two_id: ' . $user_two_id
            ]);
            exit;
        }
    }

    // Verify both chat_user_ids exist in the database
    if (!verifyChatUserExists($chat_user_one_id)) {
        http_response_code(500);
        echo json_encode([
            'action' => 'error',
            'status' => 'error',
            'message' => 'Chat user one does not exist in database: ' . $chat_user_one_id
        ]);
        exit;
    }

    if (!verifyChatUserExists($chat_user_two_id)) {
        http_response_code(500);
        echo json_encode([
            'action' => 'error',
            'status' => 'error',
            'message' => 'Chat user two does not exist in database: ' . $chat_user_two_id
        ]);
        exit;
    }

    // Check if connection already exists
    $existing_connection = getConnectionBetweenUsers($chat_user_one_id, $chat_user_two_id);
    if ($existing_connection) {
        http_response_code(200);
        echo json_encode([
            'action' => 'connection_created',
            'status' => 'success',
            'success' => true,
            'connection_id' => (string) $existing_connection,
            'is_new' => false
        ]);
        exit;
    }

    // Create new connection
    $connection_id = createChatConnection($chat_user_one_id, $chat_user_two_id);
    if ($connection_id) {
        http_response_code(200);
        echo json_encode([
            'action' => 'connection_created',
            'status' => 'success',
            'success' => true,
            'connection_id' => (string) $connection_id,
            'is_new' => true
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            'action' => 'error',
            'status' => 'error',
            'message' => 'Failed to create chat connection. Check database foreign key constraints.'
        ]);
    }

} catch (Exception $e) {
    // Log the full error for debugging
    error_log("API Error in create_connection.php: " . $e->getMessage());
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
