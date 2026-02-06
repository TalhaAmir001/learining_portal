<?php
/**
 * WebSocket Server for Real-time Chat
 *
 * This script runs a WebSocket server that handles real-time chat connections
 * for the Flutter app. It listens for connections and broadcasts messages
 * to connected clients.
 *
 * To run: php websocket_server.php
 * Or use: nohup php websocket_server.php > websocket.log 2>&1 &
 */

use Ratchet\MessageComponentInterface;
use Ratchet\ConnectionInterface;
use Ratchet\Server\IoServer;
use Ratchet\Http\HttpServer;
use Ratchet\WebSocket\WsServer;

// Define CodeIgniter constants early to avoid "No direct script access allowed" errors
if (!defined('BASEPATH')) {
    define('BASEPATH', __DIR__ . '/system/');
}
if (!defined('ENVIRONMENT')) {
    define('ENVIRONMENT', 'production');
}

require __DIR__ . '/vendor/autoload.php';
require __DIR__ . '/fcm_notification_helper.php';

// Load CodeIgniter database configuration
// We'll load it in each method to ensure fresh connection

class ChatWebSocketServer implements MessageComponentInterface
{
    protected $clients;
    protected $users; // Map user_id to connection
    protected $fcmHelper; // FCM notification helper

    public function __construct()
    {
        $this->clients = new \SplObjectStorage;
        $this->users = [];
        $this->fcmHelper = new FCMNotificationHelper();
    }

    public function onOpen(ConnectionInterface $conn)
    {
        $this->clients->attach($conn);
        echo "New connection! ({$conn->resourceId})\n";
    }

    public function onMessage(ConnectionInterface $from, $msg)
    {
        echo "Received raw message: " . substr($msg, 0, 200) . "\n";

        $data = json_decode($msg, true);

        if (!$data) {
            $json_error = json_last_error_msg();
            echo "JSON decode failed: {$json_error}\n";
            echo "Raw message was: {$msg}\n";
            $from->send(json_encode([
                'action' => 'error',
                'message' => 'Invalid JSON format: ' . $json_error
            ]));
            return;
        }

        $action = $data['action'] ?? '';
        echo "Action received: {$action}\n";

        switch ($action) {
            case 'connect':
                // User connects with their user_id
                $user_id = $data['user_id'] ?? null;
                $user_type = $data['user_type'] ?? 'staff';

                if ($user_id) {
                    $this->users[$user_id] = $from;
                    $from->user_id = $user_id;
                    $from->user_type = $user_type;

                    echo "User {$user_id} connected\n";

                    // Send confirmation
                    $from->send(json_encode([
                        'action' => 'connected',
                        'user_id' => $user_id,
                        'status' => 'success'
                    ]));
                }
                break;

            case 'send_message':
                // Handle incoming message from Flutter app
                $chat_connection_id = $data['chat_connection_id'] ?? null;
                $message = $data['message'] ?? '';
                $sender_id = $data['sender_id'] ?? null; // This is staff_id or student_id
                // Get user_type from connection object (stored during connect) or from data
                $user_type = isset($from->user_type) ? $from->user_type : ($data['user_type'] ?? 'staff');

                if ($chat_connection_id && $message && $sender_id) {
                    // Get sender's chat_user_id from fl_chat_users table
                    $sender_chat_user_id = $this->getChatUserId($sender_id, $user_type);

                    if (!$sender_chat_user_id) {
                        $from->send(json_encode([
                            'action' => 'error',
                            'message' => 'Sender chat_user_id not found. Please ensure user exists in fl_chat_users table.'
                        ]));
                        break;
                    }

                    // Get receiver's chat_user_id from chat_connection
                    $receiver_chat_user_id = $this->getReceiverChatUserId($chat_connection_id, $sender_chat_user_id);

                    if (!$receiver_chat_user_id) {
                        $from->send(json_encode([
                            'action' => 'error',
                            'message' => 'Receiver chat_user_id not found. Invalid chat_connection_id.'
                        ]));
                        break;
                    }

                    // Get client IP address
                    $client_ip = $this->getClientIp($from);

                    // Prepare data for saving
                    $message_data = [
                        'chat_connection_id' => $chat_connection_id,
                        'chat_user_id' => $receiver_chat_user_id, // Receiver's chat_user_id
                        'message' => $message,
                        'ip' => $client_ip,
                        'time' => time()
                    ];

                    // Save message to database
                    $message_id = $this->saveMessage($message_data);

                    if ($message_id) {
                        // Get receiver's actual user_id (staff_id/student_id) for broadcasting
                        $receiver_user_id = $this->getReceiverUserId($chat_connection_id, $sender_chat_user_id);
                        $receiver_user_type = $this->getReceiverUserType($chat_connection_id, $sender_chat_user_id);

                        // Broadcast to receiver if connected via WebSocket
                        if ($receiver_user_id && isset($this->users[$receiver_user_id])) {
                            $this->users[$receiver_user_id]->send(json_encode([
                                'action' => 'new_message',
                                'message_id' => $message_id,
                                'chat_connection_id' => $chat_connection_id,
                                'chat_user_id' => $receiver_chat_user_id,
                                'message' => $message,
                                'sender_id' => $sender_id,
                                'created_at' => date('Y-m-d H:i:s')
                            ]));
                            echo "Message delivered via WebSocket to user $receiver_user_id\n";
                        } else {
                            // Receiver not connected via WebSocket - send FCM notification
                            // This handles cases where app is closed or in background
                            if ($receiver_user_id && $receiver_user_type) {
                                echo "Receiver $receiver_user_id not connected via WebSocket, sending FCM notification...\n";
                                $this->fcmHelper->sendMessageNotification(
                                    $receiver_user_id,
                                    $receiver_user_type,
                                    $sender_id,
                                    $user_type,
                                    $message,
                                    $chat_connection_id
                                );
                            }
                        }

                        // Confirm to sender
                        $from->send(json_encode([
                            'action' => 'message_sent',
                            'message_id' => $message_id,
                            'status' => 'success'
                        ]));
                    } else {
                        $from->send(json_encode([
                            'action' => 'error',
                            'message' => 'Failed to save message to database'
                        ]));
                    }
                } else {
                    $from->send(json_encode([
                        'action' => 'error',
                        'message' => 'Missing required fields: chat_connection_id, message, sender_id'
                    ]));
                }
                break;

            case 'get_messages':
                // Get messages for a chat connection
                $chat_connection_id = $data['chat_connection_id'] ?? null;
                if ($chat_connection_id) {
                    // Get current user's ID from connection to determine sender for each message
                    $current_user_id = isset($from->user_id) ? $from->user_id : null;
                    $current_user_type = isset($from->user_type) ? $from->user_type : 'staff';
                    $messages = $this->getMessages($chat_connection_id, $current_user_id, $current_user_type);
                    $from->send(json_encode([
                        'action' => 'messages',
                        'chat_connection_id' => $chat_connection_id,
                        'messages' => $messages
                    ]));
                }
                break;

            case 'get_connections':
                // Get all chat connections for a user
                $user_id = $data['user_id'] ?? null;
                $user_type = isset($from->user_type) ? $from->user_type : ($data['user_type'] ?? 'staff');

                if (!$user_id) {
                    $from->send(json_encode([
                        'action' => 'error',
                        'message' => 'Missing user_id'
                    ]));
                    break;
                }

                // Get user's chat_user_id
                $chat_user_id = $this->getChatUserId($user_id, $user_type);
                if (!$chat_user_id) {
                    $from->send(json_encode([
                        'action' => 'connections',
                        'status' => 'success',
                        'connections' => []
                    ]));
                    break;
                }

                // Get all connections for this chat_user_id
                $connections = $this->getUserConnections($chat_user_id);
                
                $from->send(json_encode([
                    'action' => 'connections',
                    'status' => 'success',
                    'connections' => $connections
                ]));
                break;

            case 'create_connection':
                // Create a chat connection between two users
                $user_one_id = $data['user_one_id'] ?? null;
                $user_one_type = $data['user_one_type'] ?? 'staff';
                $user_two_id = $data['user_two_id'] ?? null;
                $user_two_type = $data['user_two_type'] ?? 'student';

                if (!$user_one_id || !$user_two_id) {
                    $from->send(json_encode([
                        'action' => 'error',
                        'message' => 'Missing user_one_id or user_two_id'
                    ]));
                    break;
                }

                // Ensure both users exist in fl_chat_users
                echo "Creating connection: user_one_id={$user_one_id} (type: {$user_one_type}), user_two_id={$user_two_id} (type: {$user_two_type})\n";
                
                $chat_user_one_id = $this->getChatUserId($user_one_id, $user_one_type);
                if (!$chat_user_one_id) {
                    echo "Chat user one not found, creating...\n";
                    // Try to create it
                    $chat_user_one_id = $this->createChatUser($user_one_id, $user_one_type);
                    if (!$chat_user_one_id) {
                        echo "Failed to create chat user one\n";
                        $from->send(json_encode([
                            'action' => 'error',
                            'message' => 'Failed to get or create chat user for user_one_id: ' . $user_one_id
                        ]));
                        break;
                    }
                }
                echo "Chat user one ID: {$chat_user_one_id}\n";

                $chat_user_two_id = $this->getChatUserId($user_two_id, $user_two_type);
                if (!$chat_user_two_id) {
                    echo "Chat user two not found, creating...\n";
                    // Try to create it
                    $chat_user_two_id = $this->createChatUser($user_two_id, $user_two_type);
                    if (!$chat_user_two_id) {
                        echo "Failed to create chat user two\n";
                        $from->send(json_encode([
                            'action' => 'error',
                            'message' => 'Failed to get or create chat user for user_two_id: ' . $user_two_id
                        ]));
                        break;
                    }
                }
                echo "Chat user two ID: {$chat_user_two_id}\n";

                // Verify both chat_user_ids exist in the database
                if (!$this->verifyChatUserExists($chat_user_one_id)) {
                    echo "ERROR: chat_user_one_id {$chat_user_one_id} does not exist in fl_chat_users table\n";
                    $from->send(json_encode([
                        'action' => 'error',
                        'message' => 'Chat user one does not exist in database: ' . $chat_user_one_id
                    ]));
                    break;
                }

                if (!$this->verifyChatUserExists($chat_user_two_id)) {
                    echo "ERROR: chat_user_two_id {$chat_user_two_id} does not exist in fl_chat_users table\n";
                    $from->send(json_encode([
                        'action' => 'error',
                        'message' => 'Chat user two does not exist in database: ' . $chat_user_two_id
                    ]));
                    break;
                }

                // Check if connection already exists
                $existing_connection = $this->getConnectionBetweenUsers($chat_user_one_id, $chat_user_two_id);
                if ($existing_connection) {
                    echo "Connection already exists: {$existing_connection}\n";
                    $from->send(json_encode([
                        'action' => 'connection_created',
                        'status' => 'success',
                        'connection_id' => $existing_connection,
                        'is_new' => false
                    ]));
                    break;
                }

                // Create new connection
                echo "Creating new connection between chat_user_one_id={$chat_user_one_id} and chat_user_two_id={$chat_user_two_id}\n";
                $connection_id = $this->createChatConnection($chat_user_one_id, $chat_user_two_id);
                if ($connection_id) {
                    echo "Connection created successfully: {$connection_id}\n";
                    $from->send(json_encode([
                        'action' => 'connection_created',
                        'status' => 'success',
                        'connection_id' => $connection_id,
                        'is_new' => true
                    ]));
                } else {
                    echo "Failed to create connection\n";
                    $from->send(json_encode([
                        'action' => 'error',
                        'message' => 'Failed to create chat connection. Check database foreign key constraints.'
                    ]));
                }
                break;

            default:
                echo "Unknown action received: {$action}\n";
                echo "Full data: " . json_encode($data) . "\n";
                $from->send(json_encode([
                    'action' => 'error',
                    'message' => 'Unknown action: ' . $action
                ]));
                break;
        }
    }

    private function createChatUser($user_id, $user_type = 'staff')
    {
        echo "createChatUser called: user_id={$user_id}, user_type={$user_type}\n";

        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            echo "✗ Database connection failed\n";
            return null;
        }
        echo "✓ Database connection established\n";

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

        echo "Executing SQL: {$sql}\n";

        if ($mysqli->query($sql)) {
            echo "✓ SQL query executed successfully\n";
            // Get the chat_user_id (either newly inserted or existing)
            $chat_user_id = $this->getChatUserId($user_id, $user_type);
            echo "Retrieved chat_user_id: " . ($chat_user_id ? $chat_user_id : 'null') . "\n";
            $mysqli->close();
            return $chat_user_id;
        } else {
            echo "✗ SQL query failed: " . $mysqli->error . "\n";
            echo "Error code: " . $mysqli->errno . "\n";
        }

        $mysqli->close();
        return null;
    }

    public function onClose(ConnectionInterface $conn)
    {
        $this->clients->detach($conn);

        // Remove user from users array
        if (isset($conn->user_id)) {
            unset($this->users[$conn->user_id]);
            echo "User {$conn->user_id} disconnected\n";
        } else {
            echo "Connection {$conn->resourceId} disconnected\n";
        }
    }

    public function onError(ConnectionInterface $conn, \Exception $e)
    {
        echo "An error has occurred: {$e->getMessage()}\n";
        $conn->close();
    }

    /**
     * Get client IP address from connection
     */
    private function getClientIp(ConnectionInterface $conn)
    {
        try {
            // Ratchet connections have remoteAddress property
            // Format is usually "tcp://IP:PORT" or just the IP
            $remote = $conn->remoteAddress ?? null;

            if ($remote) {
                // Extract IP from format like "tcp://127.0.0.1:12345"
                if (preg_match('/tcp:\/\/([^:]+)/', $remote, $matches)) {
                    return $matches[1];
                }
                // If it's already just an IP
                if (filter_var($remote, FILTER_VALIDATE_IP)) {
                    return $remote;
                }
            }
        } catch (\Exception $e) {
            // If we can't get the IP, use fallback
        }

        // Fallback: try to get from $_SERVER if available
        if (isset($_SERVER['REMOTE_ADDR'])) {
            return $_SERVER['REMOTE_ADDR'];
        }

        // Default fallback
        return '127.0.0.1';
    }

    /**
     * Get database connection
     */
    private function getDbConnection()
    {
        // Define CodeIgniter constants to bypass security check
        if (!defined('BASEPATH')) {
            define('BASEPATH', __DIR__ . '/system/');
        }
        if (!defined('ENVIRONMENT')) {
            define('ENVIRONMENT', 'production');
        }

        // Load database config
        require __DIR__ . '/application/config/database.php';
        $db_config = $db['default'];

        $mysqli = new mysqli(
            $db_config['hostname'],
            $db_config['username'],
            $db_config['password'],
            $db_config['database']
        );

        if ($mysqli->connect_error) {
            return null;
        }

        return $mysqli;
    }

    /**
     * Save message to database
     */
    private function saveMessage($data)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return false;
        }

        $chat_connection_id = $mysqli->real_escape_string($data['chat_connection_id']);
        $chat_user_id = $mysqli->real_escape_string($data['chat_user_id']);
        $message = $mysqli->real_escape_string($data['message']);
        $ip = isset($data['ip']) ? $mysqli->real_escape_string($data['ip']) : '127.0.0.1';
        $time = isset($data['time']) ? intval($data['time']) : time(); // Unix timestamp
        $created_at = date('Y-m-d H:i:s');

        $sql = "INSERT INTO fl_chat_messages (chat_connection_id, chat_user_id, message, ip, time, created_at, is_read)
                VALUES ('$chat_connection_id', '$chat_user_id', '$message', '$ip', $time, '$created_at', 0)";

        if ($mysqli->query($sql)) {
            $message_id = $mysqli->insert_id;
            $mysqli->close();
            return $message_id;
        }

        $mysqli->close();
        return false;
    }

    /**
     * Get chat_user_id from staff_id or student_id
     */
    private function getChatUserId($user_id, $user_type = 'staff')
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
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
            $chat_user_id = intval($row['id']); // Ensure it's an integer
            $mysqli->close();
            return $chat_user_id;
        }

        $mysqli->close();
        return null;
    }

    /**
     * Get receiver's chat_user_id from chat_connection
     */
    private function getReceiverChatUserId($chat_connection_id, $sender_chat_user_id)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }

        $chat_connection_id = $mysqli->real_escape_string($chat_connection_id);
        $sender_chat_user_id = $mysqli->real_escape_string($sender_chat_user_id);

        $sql = "SELECT chat_user_one, chat_user_two FROM fl_chat_connections WHERE id = '$chat_connection_id' LIMIT 1";
        $result = $mysqli->query($sql);

        if ($result && $row = $result->fetch_assoc()) {
            $receiver_chat_user_id = ($row['chat_user_one'] == $sender_chat_user_id)
                ? $row['chat_user_two']
                : $row['chat_user_one'];
            $mysqli->close();
            return $receiver_chat_user_id;
        }

        $mysqli->close();
        return null;
    }

    /**
     * Get receiver's actual user_id (staff_id/student_id) for broadcasting
     */
    private function getReceiverUserId($chat_connection_id, $sender_chat_user_id)
    {
        $receiver_chat_user_id = $this->getReceiverChatUserId($chat_connection_id, $sender_chat_user_id);
        if (!$receiver_chat_user_id) {
            return null;
        }

        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }

        $receiver_chat_user_id = $mysqli->real_escape_string($receiver_chat_user_id);
        $sql = "SELECT staff_id, student_id FROM fl_chat_users WHERE id = '$receiver_chat_user_id' LIMIT 1";
        $result = $mysqli->query($sql);

        if ($result && $row = $result->fetch_assoc()) {
            $user_id = $row['staff_id'] ? $row['staff_id'] : $row['student_id'];
            $mysqli->close();
            return $user_id;
        }

        $mysqli->close();
        return null;
    }

    /**
     * Get receiver's user_type for FCM notifications
     */
    private function getReceiverUserType($chat_connection_id, $sender_chat_user_id)
    {
        $receiver_chat_user_id = $this->getReceiverChatUserId($chat_connection_id, $sender_chat_user_id);
        if (!$receiver_chat_user_id) {
            return null;
        }

        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }

        $receiver_chat_user_id = $mysqli->real_escape_string($receiver_chat_user_id);
        $sql = "SELECT user_type FROM fl_chat_users WHERE id = '$receiver_chat_user_id' LIMIT 1";
        $result = $mysqli->query($sql);

        if ($result && $row = $result->fetch_assoc()) {
            $user_type = $row['user_type'];
            $mysqli->close();
            return $user_type;
        }

        $mysqli->close();
        return null;
    }

    /**
     * Get receiver user_id from chat_connection (legacy method - kept for compatibility)
     */
    private function getReceiverId($chat_connection_id, $sender_id)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }

        $chat_connection_id = $mysqli->real_escape_string($chat_connection_id);
        $sender_id = $mysqli->real_escape_string($sender_id);

        $sql = "SELECT chat_user_one, chat_user_two FROM fl_chat_connections WHERE id = '$chat_connection_id'";
        $result = $mysqli->query($sql);

        if ($result && $row = $result->fetch_assoc()) {
            $receiver_id = ($row['chat_user_one'] == $sender_id) ? $row['chat_user_two'] : $row['chat_user_one'];
            $mysqli->close();
            return $receiver_id;
        }

        $mysqli->close();
        return null;
    }

    /**
     * Get messages for a chat connection with sender information
     */
    private function getMessages($chat_connection_id, $current_user_id = null, $current_user_type = 'staff')
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return [];
        }

        $chat_connection_id = $mysqli->real_escape_string($chat_connection_id);
        
        // Get the chat connection to know both users
        $conn_sql = "SELECT chat_user_one, chat_user_two FROM fl_chat_connections WHERE id = '$chat_connection_id' LIMIT 1";
        $conn_result = $mysqli->query($conn_sql);
        
        if (!$conn_result || !($conn_row = $conn_result->fetch_assoc())) {
            $mysqli->close();
            return [];
        }
        
        $chat_user_one_id = intval($conn_row['chat_user_one']);
        $chat_user_two_id = intval($conn_row['chat_user_two']);
        
        // Get messages with sender information
        $sql = "SELECT m.*, 
                       cu1.staff_id as user_one_staff_id, 
                       cu1.student_id as user_one_student_id,
                       cu2.staff_id as user_two_staff_id, 
                       cu2.student_id as user_two_student_id
                FROM fl_chat_messages m
                LEFT JOIN fl_chat_users cu1 ON cu1.id = '$chat_user_one_id'
                LEFT JOIN fl_chat_users cu2 ON cu2.id = '$chat_user_two_id'
                WHERE m.chat_connection_id = '$chat_connection_id' 
                ORDER BY m.created_at ASC, m.id ASC";
        
        $result = $mysqli->query($sql);
        $messages = [];

        if ($result) {
            while ($row = $result->fetch_assoc()) {
                // Determine sender: chat_user_id is the receiver, so sender is the other user
                $receiver_chat_user_id = intval($row['chat_user_id']);
                $sender_chat_user_id = ($receiver_chat_user_id == $chat_user_one_id) ? $chat_user_two_id : $chat_user_one_id;
                
                // Get sender's actual user_id (staff_id or student_id)
                $sender_id = null;
                if ($sender_chat_user_id == $chat_user_one_id) {
                    $sender_id = $row['user_one_staff_id'] ?: $row['user_one_student_id'];
                } else {
                    $sender_id = $row['user_two_staff_id'] ?: $row['user_two_student_id'];
                }
                
                // Build message with sender information
                $message = [
                    'id' => $row['id'],
                    'chat_connection_id' => $row['chat_connection_id'],
                    'chat_user_id' => $row['chat_user_id'],
                    'message' => $row['message'],
                    'ip' => $row['ip'],
                    'time' => $row['time'],
                    'is_read' => $row['is_read'],
                    'created_at' => $row['created_at'],
                    'sender_id' => $sender_id ? (string)$sender_id : null, // Ensure it's a string for consistency
                ];
                
                $messages[] = $message;
            }
        }

        $mysqli->close();
        return $messages;
    }

    /**
     * Get all chat connections for a chat_user_id
     */
    private function getUserConnections($chat_user_id)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return [];
        }

        $chat_user_id = $mysqli->real_escape_string($chat_user_id);
        
        // Get connections where this user is either chat_user_one or chat_user_two
        $sql = "SELECT 
                    cc.id,
                    cc.chat_user_one,
                    cc.chat_user_two,
                    cc.created_at,
                    cu1.staff_id as user_one_staff_id,
                    cu1.student_id as user_one_student_id,
                    cu1.user_type as user_one_type,
                    cu2.staff_id as user_two_staff_id,
                    cu2.student_id as user_two_student_id,
                    cu2.user_type as user_two_type
                FROM fl_chat_connections cc
                LEFT JOIN fl_chat_users cu1 ON cc.chat_user_one = cu1.id
                LEFT JOIN fl_chat_users cu2 ON cc.chat_user_two = cu2.id
                WHERE cc.chat_user_one = '$chat_user_id' OR cc.chat_user_two = '$chat_user_id'
                ORDER BY cc.created_at DESC";
        
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
                    'created_at' => $row['created_at']
                ];
            }
        }

        $mysqli->close();
        return $connections;
    }

    /**
     * Get connection ID between two chat_user_ids (if exists)
     */
    private function getConnectionBetweenUsers($chat_user_one_id, $chat_user_two_id)
    {
        $mysqli = $this->getDbConnection();
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
     * Verify that a chat_user_id exists in the database
     */
    private function verifyChatUserExists($chat_user_id)
    {
        $mysqli = $this->getDbConnection();
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
     * Create a new chat connection between two chat_user_ids
     */
    private function createChatConnection($chat_user_one_id, $chat_user_two_id)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            echo "✗ Database connection failed\n";
            return null;
        }

        // Ensure values are integers
        $chat_user_one_id = intval($chat_user_one_id);
        $chat_user_two_id = intval($chat_user_two_id);

        if ($chat_user_one_id <= 0 || $chat_user_two_id <= 0) {
            echo "✗ Invalid chat_user_id values: one={$chat_user_one_id}, two={$chat_user_two_id}\n";
            $mysqli->close();
            return null;
        }

        // Verify both users exist before attempting insert
        if (!$this->verifyChatUserExists($chat_user_one_id)) {
            echo "✗ chat_user_one_id {$chat_user_one_id} does not exist\n";
            $mysqli->close();
            return null;
        }

        if (!$this->verifyChatUserExists($chat_user_two_id)) {
            echo "✗ chat_user_two_id {$chat_user_two_id} does not exist\n";
            $mysqli->close();
            return null;
        }

        $sql = "INSERT INTO fl_chat_connections (chat_user_one, chat_user_two, created_at, updated_at)
                VALUES ($chat_user_one_id, $chat_user_two_id, NOW(), NOW())";

        echo "Executing SQL: {$sql}\n";

        if ($mysqli->query($sql)) {
            $connection_id = $mysqli->insert_id;
            echo "✓ Connection created with ID: {$connection_id}\n";
            $mysqli->close();
            return $connection_id;
        }

        $error = $mysqli->error;
        $errno = $mysqli->errno;
        echo "✗ SQL Error ({$errno}): {$error}\n";
        echo "Attempted to insert: chat_user_one={$chat_user_one_id}, chat_user_two={$chat_user_two_id}\n";
        $mysqli->close();
        return null;
    }
}

// Start the server
$port = 8080; // WebSocket port
$server = IoServer::factory(
    new HttpServer(
        new WsServer(
            new ChatWebSocketServer()
        )
    ),
    $port
);

echo "WebSocket server started on port {$port}\n";
echo "Connect to: ws://localhost:{$port}\n";
$server->run();
