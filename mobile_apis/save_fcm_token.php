<?php
/**
 * Save FCM Token API Endpoint
 * 
 * This endpoint saves FCM tokens to the fl_chat_users table
 * so the WebSocket server can send push notifications when app is closed
 */

// Define CodeIgniter constants to bypass security check
if (!defined('BASEPATH')) {
    define('BASEPATH', __DIR__ . '/../system/');
}
if (!defined('ENVIRONMENT')) {
    define('ENVIRONMENT', 'production');
}

// Load CodeIgniter database configuration
require __DIR__ . '/../application/config/database.php';
$db_config = $db['default'];

// Get POST data
$user_id = $_POST['user_id'] ?? null;
$user_type = $_POST['user_type'] ?? 'staff';
$fcm_token = $_POST['fcm_token'] ?? null;

// Validate input
if (empty($user_id) || empty($fcm_token)) {
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => 'Missing required fields: user_id and fcm_token are required'
    ]);
    exit;
}

// Validate user_type
if ($user_type !== 'staff' && $user_type !== 'student') {
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => 'Invalid user_type. Must be "staff" or "student"'
    ]);
    exit;
}

try {
    // Connect to database
    $mysqli = new mysqli(
        $db_config['hostname'],
        $db_config['username'],
        $db_config['password'],
        $db_config['database']
    );

    if ($mysqli->connect_error) {
        throw new Exception('Database connection failed: ' . $mysqli->connect_error);
    }

    // Escape input
    $user_id = $mysqli->real_escape_string($user_id);
    $user_type = $mysqli->real_escape_string($user_type);
    $fcm_token = $mysqli->real_escape_string($fcm_token);

    // Find the chat_user_id for this user
    if ($user_type == 'staff') {
        $find_sql = "SELECT id FROM fl_chat_users WHERE staff_id = '$user_id' AND user_type = 'staff' LIMIT 1";
    } else {
        $find_sql = "SELECT id FROM fl_chat_users WHERE student_id = '$user_id' AND user_type = 'student' LIMIT 1";
    }

    $result = $mysqli->query($find_sql);
    
    if (!$result) {
        throw new Exception('Database query failed: ' . $mysqli->error);
    }

    if ($result->num_rows > 0) {
        // User exists, update FCM token
        $row = $result->fetch_assoc();
        $chat_user_id = $row['id'];
        
        $update_sql = "UPDATE fl_chat_users SET fcm_token = '$fcm_token', updated_at = NOW() WHERE id = $chat_user_id";
        
        if ($mysqli->query($update_sql)) {
            $mysqli->close();
            header('Content-Type: application/json');
            echo json_encode([
                'success' => true,
                'status' => 'success',
                'message' => 'FCM token saved successfully',
                'chat_user_id' => $chat_user_id
            ]);
            exit;
        } else {
            throw new Exception('Failed to update FCM token: ' . $mysqli->error);
        }
    } else {
        // User doesn't exist in fl_chat_users table
        // This shouldn't happen if chat user was created during login
        // But we'll return an error message
        $mysqli->close();
        header('Content-Type: application/json');
        echo json_encode([
            'success' => false,
            'error' => 'Chat user not found. Please ensure user exists in fl_chat_users table. User may need to log in again.'
        ]);
        exit;
    }

} catch (Exception $e) {
    if (isset($mysqli)) {
        $mysqli->close();
    }
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
    exit;
}
