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
    /** Virtual Support user: staff_id = 0 in fl_chat_users. Students/teachers chat with Support; any admin can reply. */
    const SUPPORT_STAFF_ID = 0;

    protected $clients;
    protected $users; // Map user_id to connection
    protected $staffConnections; // All staff (admin) connections for broadcasting Support messages
    protected $fcmHelper; // FCM notification helper

    public function __construct()
    {
        $this->clients = new \SplObjectStorage;
        $this->users = [];
        $this->staffConnections = new \SplObjectStorage;
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

                if ($user_id !== null && $user_id !== '') {
                    $this->users[$user_id] = $from;
                    $from->user_id = $user_id;
                    $from->user_type = $user_type;
                    if ($user_type === 'staff') {
                        $this->staffConnections->attach($from);
                    }

                    echo "User {$user_id} ({$user_type}) connected\n";

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

                if ($chat_connection_id && $message && $sender_id !== null) {
                    try {
                        $support_chat_user_id = $this->getSupportChatUserId();
                        $sender_chat_user_id = $this->getChatUserId($sender_id, $user_type);

                        // Support conversation: admin may send on behalf of Support (connection is student/teacher <-> Support)
                        $connection_is_support = $this->connectionContainsSupport($chat_connection_id, $support_chat_user_id);
                        $admin_replying_as_support = $connection_is_support && $user_type === 'staff' && $sender_chat_user_id && (int)$sender_chat_user_id !== (int)$support_chat_user_id;

                        if ($admin_replying_as_support) {
                            // Admin replying in support thread: treat sender as Support, receiver as student/teacher
                            $effective_sender_chat_user_id = $support_chat_user_id;
                            $effective_receiver_chat_user_id = $this->getOtherPartyInConnection($chat_connection_id, $support_chat_user_id);
                        } else {
                            $effective_sender_chat_user_id = $sender_chat_user_id;
                            $effective_receiver_chat_user_id = $sender_chat_user_id ? $this->getReceiverChatUserId($chat_connection_id, $sender_chat_user_id) : null;
                        }

                        if (!$effective_sender_chat_user_id || !$effective_receiver_chat_user_id) {
                            if (!$admin_replying_as_support && !$sender_chat_user_id) {
                                $from->send(json_encode([
                                    'action' => 'error',
                                    'message' => 'Sender chat_user_id not found. Please ensure user exists in fl_chat_users table.'
                                ]));
                                echo "send_message: error - sender chat_user_id not found\n";
                                break;
                            }
                            $from->send(json_encode([
                                'action' => 'error',
                                'message' => 'Receiver chat_user_id not found. Invalid chat_connection_id.'
                            ]));
                            echo "send_message: error - receiver chat_user_id not found\n";
                            break;
                        }

                        echo "send_message: effective_sender=$effective_sender_chat_user_id, effective_receiver=$effective_receiver_chat_user_id (connection_id=$chat_connection_id)\n";
                        @ob_flush(); @flush();

                        $client_ip = $this->getClientIp($from);
                        $message_data = [
                            'chat_connection_id' => $chat_connection_id,
                            'chat_user_id' => $effective_receiver_chat_user_id,
                            'message' => $message,
                            'ip' => $client_ip,
                            'time' => time()
                        ];

                        $message_id = $this->saveMessage($message_data);
                        echo "send_message: message_id=" . ($message_id ?: 'null') . "\n";
                        @ob_flush(); @flush();

                        if ($message_id) {
                            $receiver_user_id = $this->getReceiverUserIdFromChatUserId($chat_connection_id, $effective_receiver_chat_user_id);
                            $receiver_user_type = $this->getReceiverUserTypeFromChatUserId($effective_receiver_chat_user_id);
                            $sender_id_for_delivery = $admin_replying_as_support ? (string) self::SUPPORT_STAFF_ID : $sender_id;
                            echo "send_message: receiver_user_id=$receiver_user_id, receiver_user_type=$receiver_user_type\n";
                            @ob_flush(); @flush();

                            // Deliver: if receiver is Support (staff_id=0), broadcast to all staff; else single user
                            if ($receiver_user_id !== null && (int)$receiver_user_id !== (int) self::SUPPORT_STAFF_ID && isset($this->users[$receiver_user_id])) {
                                try {
                                    $this->users[$receiver_user_id]->send(json_encode([
                                        'action' => 'new_message',
                                        'message_id' => $message_id,
                                        'chat_connection_id' => $chat_connection_id,
                                        'chat_user_id' => $effective_receiver_chat_user_id,
                                        'message' => $message,
                                        'sender_id' => $sender_id_for_delivery,
                                        'created_at' => date('Y-m-d H:i:s')
                                    ]));
                                    echo "Message delivered via WebSocket to user $receiver_user_id\n";
                                } catch (\Exception $e) {
                                    echo "WebSocket send failed for user $receiver_user_id: {$e->getMessage()}, removing from users\n";
                                    unset($this->users[$receiver_user_id]);
                                }
                            } elseif ($receiver_user_id !== null && (int)$receiver_user_id === (int) self::SUPPORT_STAFF_ID) {
                                foreach ($this->staffConnections as $staffConn) {
                                    try {
                                        $staffConn->send(json_encode([
                                            'action' => 'new_message',
                                            'message_id' => $message_id,
                                            'chat_connection_id' => $chat_connection_id,
                                            'chat_user_id' => $effective_receiver_chat_user_id,
                                            'message' => $message,
                                            'sender_id' => $sender_id,
                                            'created_at' => date('Y-m-d H:i:s')
                                        ]));
                                    } catch (\Exception $e) {
                                        // ignore per-connection errors
                                    }
                                }
                                echo "Message broadcast to " . $this->staffConnections->count() . " staff (Support inbox)\n";
                            } else {
                                echo "Receiver $receiver_user_id not in WebSocket users\n";
                            }

                            if ($receiver_user_id && $receiver_user_type && (int)$receiver_user_id !== (int) self::SUPPORT_STAFF_ID) {
                                echo "Sending FCM notification to receiver $receiver_user_id...\n";
                                @ob_flush(); @flush();
                                $this->fcmHelper->sendMessageNotification(
                                    $receiver_user_id,
                                    $receiver_user_type,
                                    $sender_id_for_delivery,
                                    $admin_replying_as_support ? 'staff' : $user_type,
                                    $message,
                                    $chat_connection_id
                                );
                                echo "FCM sendMessageNotification completed for receiver $receiver_user_id\n";
                            } else {
                                echo "send_message: skip FCM - receiver is Support or missing\n";
                            }

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
                            echo "send_message: error - saveMessage returned no message_id\n";
                        }
                    } catch (\Throwable $e) {
                        echo "send_message exception: " . $e->getMessage() . "\n" . $e->getTraceAsString() . "\n";
                        @ob_flush(); @flush();
                        $from->send(json_encode([
                            'action' => 'error',
                            'message' => 'Server error: ' . $e->getMessage()
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
            case 'create_chat_user':
                echo "=== CREATE_CHAT_USER REQUEST RECEIVED ===\n";
                echo "Full data: " . json_encode($data) . "\n";

                // Handle both string and integer user_id
                $user_id_raw = $data['user_id'] ?? null;
                $user_id = $user_id_raw !== null ? intval($user_id_raw) : null;
                $user_type = isset($data['user_type']) ? trim($data['user_type']) : 'staff';

                echo "Processing: user_id={$user_id} (raw: " . var_export($user_id_raw, true) . "), user_type='{$user_type}'\n";

                if (!$user_id) {
                    echo "Error: Missing user_id\n";
                    $from->send(json_encode([
                        'action' => 'error',
                        'message' => 'Missing user_id'
                    ]));
                    break;
                }

                if (!in_array($user_type, ['staff', 'student'])) {
                    echo "Error: Invalid user_type={$user_type}\n";
                    $from->send(json_encode([
                        'action' => 'error',
                        'message' => 'Invalid user_type. Must be "staff" or "student"'
                    ]));
                    break;
                }

                // Check if chat user already exists
                echo "Checking if chat user exists...\n";
                $chat_user_id = $this->getChatUserId($user_id, $user_type);
                $is_new = false;

                if (!$chat_user_id) {
                    echo "Chat user not found, creating new entry...\n";
                    // Create new chat user entry
                    $chat_user_id = $this->createChatUser($user_id, $user_type);
                    $is_new = true;
                    echo "createChatUser returned: " . ($chat_user_id ? $chat_user_id : 'null') . "\n";
                } else {
                    echo "Chat user already exists with ID: {$chat_user_id}\n";
                }

                if ($chat_user_id) {
                    $response = [
                        'action' => 'chat_user_created',
                        'chat_user_id' => $chat_user_id,
                        'is_new' => $is_new,
                        'status' => 'success'
                    ];
                    $response_json = json_encode($response);
                    echo "Sending success response: {$response_json}\n";

                    try {
                        $from->send($response_json);
                        echo "✓ Response sent successfully\n";
                        echo "Chat user " . ($is_new ? "created" : "verified") . " for user {$user_id} ({$user_type}) with chat_user_id: {$chat_user_id}\n";
                    } catch (\Exception $e) {
                        echo "✗ ERROR sending response: " . $e->getMessage() . "\n";
                        echo "Exception trace: " . $e->getTraceAsString() . "\n";
                    }
                } else {
                    echo "✗ Error: Failed to create/get chat user entry\n";
                    $error_response = json_encode([
                        'action' => 'error',
                        'message' => 'Failed to create chat user entry. Check database connection and table structure.'
                    ]);
                    echo "Sending error response: {$error_response}\n";
                    try {
                        $from->send($error_response);
                        echo "✓ Error response sent\n";
                    } catch (\Exception $e) {
                        echo "✗ ERROR sending error response: " . $e->getMessage() . "\n";
                    }
                }
                echo "=== CREATE_CHAT_USER REQUEST COMPLETED ===\n\n";
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
        $this->staffConnections->detach($conn);

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
     * Get Support (virtual) chat_user_id (staff_id = 0, user_type = staff)
     */
    private function getSupportChatUserId()
    {
        return $this->getChatUserId((string) self::SUPPORT_STAFF_ID, 'staff');
    }

    /**
     * Check if a connection involves the Support chat user
     */
    private function connectionContainsSupport($chat_connection_id, $support_chat_user_id)
    {
        if (!$support_chat_user_id) {
            return false;
        }
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return false;
        }
        $chat_connection_id = $mysqli->real_escape_string($chat_connection_id);
        $support_chat_user_id = $mysqli->real_escape_string($support_chat_user_id);
        $sql = "SELECT id FROM fl_chat_connections WHERE id = '$chat_connection_id' AND (chat_user_one = '$support_chat_user_id' OR chat_user_two = '$support_chat_user_id') LIMIT 1";
        $result = $mysqli->query($sql);
        $has = $result && $result->num_rows > 0;
        $mysqli->close();
        return $has;
    }

    /**
     * Get the other party's chat_user_id in a connection (given one side)
     */
    private function getOtherPartyInConnection($chat_connection_id, $one_chat_user_id)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }
        $chat_connection_id = $mysqli->real_escape_string($chat_connection_id);
        $one_chat_user_id = $mysqli->real_escape_string($one_chat_user_id);
        $sql = "SELECT chat_user_one, chat_user_two FROM fl_chat_connections WHERE id = '$chat_connection_id' LIMIT 1";
        $result = $mysqli->query($sql);
        if (!$result || !$row = $result->fetch_assoc()) {
            $mysqli->close();
            return null;
        }
        $other = ($row['chat_user_one'] == $one_chat_user_id) ? $row['chat_user_two'] : $row['chat_user_one'];
        $mysqli->close();
        return $other;
    }

    /**
     * Get receiver's actual user_id (staff_id/student_id) when we know receiver's chat_user_id
     */
    private function getReceiverUserIdFromChatUserId($chat_connection_id, $receiver_chat_user_id)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }
        $receiver_chat_user_id = $mysqli->real_escape_string($receiver_chat_user_id);
        $sql = "SELECT staff_id, student_id FROM fl_chat_users WHERE id = '$receiver_chat_user_id' LIMIT 1";
        $result = $mysqli->query($sql);
        if ($result && $row = $result->fetch_assoc()) {
            $user_id = $row['staff_id'] !== null ? $row['staff_id'] : $row['student_id'];
            $mysqli->close();
            return $user_id !== null ? (string) $user_id : null;
        }
        $mysqli->close();
        return null;
    }

    /**
     * Get user_type for a chat_user_id
     */
    private function getReceiverUserTypeFromChatUserId($chat_user_id)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }
        $chat_user_id = $mysqli->real_escape_string($chat_user_id);
        $sql = "SELECT user_type FROM fl_chat_users WHERE id = '$chat_user_id' LIMIT 1";
        $result = $mysqli->query($sql);
        if ($result && $row = $result->fetch_assoc()) {
            $ut = $row['user_type'];
            $mysqli->close();
            return $ut;
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


//retrieve lists from REST and use websocket to only listen data changes