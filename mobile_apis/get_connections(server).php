<?php
/**
 * Standalone PHP API for Getting Chat Connections
 * 
 * This API endpoint can be used by mobile apps to get all chat connections
 * for a user without going through CodeIgniter's routing system.
 * 
 * It does the same job as the get_connections action in websocket_server.php
 * 
 * Usage:
 * POST /mobile_apis/get_connections.php
 * 
 * Request body (JSON or form-data):
 * {
 *   "user_id": 123,
 *   "user_type": "staff" or "student"
 * }
 * 
 * Response:
 * {
 *   "action": "connections",
 *   "status": "success",
 *   "connections": [
 *     {
 *       "id": 123,
 *       "chat_user_one": 1,
 *       "chat_user_two": 2,
 *       "other_user_id": 456,
 *       "other_user_type": "student",
 *       "created_at": "2024-01-01 12:00:00",
 *       "last_message": {
 *         "id": 789,
 *         "message": "Hello!",
 *         "sender_id": "123",
 *         "sender_chat_user_id": 1,
 *         "receiver_chat_user_id": 2,
 *         "is_read": 0,
 *         "created_at": "2024-01-01 13:00:00",
 *         "time": 1704110400
 *       } or null if no messages
 *     }
 *   ]
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
 * Get all chat connections for a chat_user_id with last message
 */
function getUserConnections($chat_user_id)
{
    $mysqli = getDbConnection();
    if (!$mysqli) {
        return [];
    }

    $chat_user_id = $mysqli->real_escape_string($chat_user_id);
    
    // Get connections where this user is either chat_user_one or chat_user_two
    // Also get the last message for each connection using a subquery
    // support_claimed_by_staff_id: when set, only that staff sees this support thread
    $sql = "SELECT 
                cc.id,
                cc.chat_user_one,
                cc.chat_user_two,
                cc.created_at,
                cc.support_claimed_by_staff_id,
                cu1.staff_id as user_one_staff_id,
                cu1.student_id as user_one_student_id,
                cu1.user_type as user_one_type,
                cu2.staff_id as user_two_staff_id,
                cu2.student_id as user_two_student_id,
                cu2.user_type as user_two_type,
                m.id as last_message_id,
                m.message as last_message,
                m.chat_user_id as last_message_receiver_chat_user_id,
                m.is_read as last_message_is_read,
                m.created_at as last_message_created_at,
                m.time as last_message_time
            FROM fl_chat_connections cc
            LEFT JOIN fl_chat_users cu1 ON cc.chat_user_one = cu1.id
            LEFT JOIN fl_chat_users cu2 ON cc.chat_user_two = cu2.id
            LEFT JOIN (
                SELECT m1.*
                FROM fl_chat_messages m1
                INNER JOIN (
                    SELECT chat_connection_id, MAX(id) as max_id
                    FROM fl_chat_messages
                    GROUP BY chat_connection_id
                ) m2 ON m1.chat_connection_id = m2.chat_connection_id 
                    AND m1.id = m2.max_id
            ) m ON cc.id = m.chat_connection_id
            WHERE cc.chat_user_one = '$chat_user_id' OR cc.chat_user_two = '$chat_user_id'
            ORDER BY COALESCE(m.created_at, cc.created_at) DESC";
    
    $result = $mysqli->query($sql);
    $connections = [];

    if ($result) {
        while ($row = $result->fetch_assoc()) {
            // Determine the other user's ID
            $other_chat_user_id = ($row['chat_user_one'] == $chat_user_id) 
                ? $row['chat_user_two'] 
                : $row['chat_user_one'];
            
            // Get the other user's actual user_id (staff_id or student_id)
            $other_user_id = null;
            $other_user_type = null;
            
            if ($row['chat_user_one'] == $chat_user_id) {
                // Other user is user_two
                $other_user_id = $row['user_two_staff_id'] ?: $row['user_two_student_id'];
                $other_user_type = $row['user_two_type'];
            } else {
                // Other user is user_one
                $other_user_id = $row['user_one_staff_id'] ?: $row['user_one_student_id'];
                $other_user_type = $row['user_one_type'];
            }

            // Determine sender of last message
            // In fl_chat_messages, chat_user_id is the receiver
            // So sender is the other user in the connection
            $last_message = null;
            if ($row['last_message_id']) {
                $receiver_chat_user_id = intval($row['last_message_receiver_chat_user_id']);
                $sender_chat_user_id = ($receiver_chat_user_id == $row['chat_user_one']) 
                    ? $row['chat_user_two'] 
                    : $row['chat_user_one'];
                
                // Get sender's actual user_id
                $sender_id = null;
                if ($sender_chat_user_id == $row['chat_user_one']) {
                    $sender_id = $row['user_one_staff_id'] ?: $row['user_one_student_id'];
                } else {
                    $sender_id = $row['user_two_staff_id'] ?: $row['user_two_student_id'];
                }

                $last_message = [
                    'id' => $row['last_message_id'],
                    'message' => $row['last_message'],
                    'sender_id' => $sender_id ? (string)$sender_id : null,
                    'sender_chat_user_id' => $sender_chat_user_id,
                    'receiver_chat_user_id' => $receiver_chat_user_id,
                    'is_read' => $row['last_message_is_read'],
                    'created_at' => $row['last_message_created_at'],
                    'time' => $row['last_message_time']
                ];
            }

            $connections[] = [
                'id' => $row['id'],
                'chat_user_one' => $row['chat_user_one'],
                'chat_user_two' => $row['chat_user_two'],
                'chat_user_one_id' => $row['chat_user_one'],
                'chat_user_two_id' => $row['chat_user_two'],
                'user_one_id' => $row['user_one_staff_id'] ?: $row['user_one_student_id'],
                'user_two_id' => $row['user_two_staff_id'] ?: $row['user_two_student_id'],
                'other_user_id' => $other_user_id,
                'other_user_type' => $other_user_type,
                'created_at' => $row['created_at'],
                'last_message' => $last_message,
                'support_claimed_by_staff_id' => isset($row['support_claimed_by_staff_id']) ? $row['support_claimed_by_staff_id'] : null
            ];
        }
    }

    $mysqli->close();
    return $connections;
}

// Main API logic
try {
    // Get input data (support both JSON and form-data, GET and POST)
    $input = json_decode(file_get_contents('php://input'), true);
    if ($input) {
        $user_id_raw = isset($input['user_id']) ? $input['user_id'] : null;
        $user_type = isset($input['user_type']) ? trim($input['user_type']) : 'staff';
        $requesting_staff_id_raw = isset($input['requesting_staff_id']) ? $input['requesting_staff_id'] : null;
    } else {
        $user_id_raw = isset($_POST['user_id']) ? $_POST['user_id'] : (isset($_GET['user_id']) ? $_GET['user_id'] : null);
        $user_type = isset($_POST['user_type']) ? trim($_POST['user_type']) : (isset($_GET['user_type']) ? trim($_GET['user_type']) : 'staff');
        $requesting_staff_id_raw = isset($_POST['requesting_staff_id']) ? $_POST['requesting_staff_id'] : (isset($_GET['requesting_staff_id']) ? $_GET['requesting_staff_id'] : null);
    }
    $requesting_staff_id = $requesting_staff_id_raw !== null && $requesting_staff_id_raw !== '' ? intval($requesting_staff_id_raw) : null;

    // Handle both string and integer user_id (allow 0 for Support user / admin inbox)
    $user_id = $user_id_raw !== null && $user_id_raw !== '' ? intval($user_id_raw) : (($user_id_raw === 0 || $user_id_raw === '0') ? 0 : null);

    // Validate required fields (allow user_id = 0 for Support)
    if ($user_id === null) {
        http_response_code(400);
        echo json_encode([
            'action' => 'error',
            'status' => 'error',
            'message' => 'Missing or invalid user_id'
        ]);
        exit;
    }

    // Validate user_type
    $user_type = strtolower($user_type);
    if (!in_array($user_type, ['staff', 'student'])) {
        http_response_code(400);
        echo json_encode([
            'action' => 'error',
            'status' => 'error',
            'message' => 'Invalid user_type. Must be "staff" or "student"'
        ]);
        exit;
    }

    // Get user's chat_user_id (user_id can be 0 for Support – admin inbox)
    $chat_user_id = getChatUserId((string) $user_id, $user_type);
    if (!$chat_user_id) {
        // Return empty connections array if user doesn't exist (e.g. Support not yet created)
        http_response_code(200);
        echo json_encode([
            'action' => 'connections',
            'status' => 'success',
            'success' => true,
            'connections' => []
        ]);
        exit;
    }

    // Get all connections for this chat_user_id
    $connections = getUserConnections($chat_user_id);

    // Support inbox (user_id=0): show ALL support threads to every admin so it's a group chat (one student + multiple admins)
    // No filter by support_claimed_by_staff_id - every admin can open any thread and see full conversation in real time.

    // Return success response (success key for Flutter repository)
    http_response_code(200);
    echo json_encode([
        'action' => 'connections',
        'status' => 'success',
        'success' => true,
        'connections' => $connections
    ]);

} catch (Exception $e) {
    // Log the full error for debugging
    error_log("API Error in get_connections.php: " . $e->getMessage());
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
