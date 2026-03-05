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
    /** Virtual Support user: staff_id = 0 in fl_chat_users, user_type = 'staff'. Students/guardians/teachers chat with Support; only admins get Inbox. */
    /** fl_chat_users.user_type matches UserType enum: student, guardian, teacher, admin; plus 'staff' only for Support row. */
    const SUPPORT_STAFF_ID = 0;

    protected $clients;
    protected $users; // Map user_id to connection
    protected $staffConnections; // All staff (admin) connections for broadcasting Support messages
    /** @var \SplObjectStorage Connection -> chat_connection_id (which support thread this staff is viewing) */
    protected $staffViewingChat;
    protected $fcmHelper; // FCM notification helper
    /** Path to file written by CodeIgniter when a new notice is added (trigger broadcast) */
    protected $pendingNoticeBroadcastPath;

    public function __construct()
    {
        $this->clients = new \SplObjectStorage;
        $this->users = [];
        $this->staffConnections = new \SplObjectStorage;
        $this->staffViewingChat = new \SplObjectStorage();
        $this->fcmHelper = new FCMNotificationHelper();
        $this->pendingNoticeBroadcastPath = __DIR__ . '/application/cache/pending_notice_broadcast.json';
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
                    // Only admin (and teacher for Support inbox) get staff-side features; student/guardian/teacher get Support chat only
                    if ($this->isStaffSideUserType($user_type)) {
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
                        $admin_replying_as_support = $connection_is_support && $this->isStaffSideUserType($user_type) && $sender_chat_user_id && (int)$sender_chat_user_id !== (int)$support_chat_user_id;

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
                        $message_type = isset($data['message_type']) ? trim($data['message_type']) : 'text';
                        if (!in_array($message_type, ['text', 'image', 'document'])) {
                            $message_type = 'text';
                        }
                        $image_url = isset($data['image_url']) ? trim($data['image_url']) : null;
                        $document_url = isset($data['document_url']) ? trim($data['document_url']) : $image_url;
                        $attachment_url = ($message_type === 'image' && $image_url !== '') ? $image_url : (($message_type === 'document' && $document_url !== '') ? $document_url : null);
                        $message_data = [
                            'chat_connection_id' => $chat_connection_id,
                            'chat_user_id' => $effective_receiver_chat_user_id,
                            'message' => $message,
                            'ip' => $client_ip,
                            'time' => time(),
                            'message_type' => $message_type,
                            'image_url' => $attachment_url
                        ];
                        if ($admin_replying_as_support && $sender_id !== null) {
                            $message_data['actual_sender_staff_id'] = $sender_id;
                        }

                        $message_id = $this->saveMessage($message_data);
                        echo "send_message: message_id=" . ($message_id ?: 'null') . "\n";
                        @ob_flush(); @flush();

                        if ($message_id) {
                            $receiver_user_id = $this->getReceiverAppUserIdByChatUserRowId($effective_receiver_chat_user_id);
                            $receiver_user_type = $this->getReceiverUserTypeFromChatUserId($effective_receiver_chat_user_id);
                            $sender_id_for_delivery = $admin_replying_as_support ? (string) self::SUPPORT_STAFF_ID : $sender_id;
                            $actual_sender_staff_id = $admin_replying_as_support && $sender_id !== null ? (string) $sender_id : null;
                            $sender_display_name = null;
                            $mysqli = $this->getDbConnection();
                            if ($actual_sender_staff_id !== null) {
                                $sender_display_name = $this->getStaffDisplayName($mysqli, $sender_id);
                            } elseif ($receiver_user_id !== null && (int)$receiver_user_id === (int) self::SUPPORT_STAFF_ID && $this->isStudentSideUserType($user_type)) {
                                // Student/teacher/guardian sent to Support: get display name for staff inbox payload
                                $ut = strtolower(trim((string) $user_type));
                                if ($ut === 'teacher') {
                                    $sender_display_name = $this->getStaffDisplayName($mysqli, $sender_id);
                                } elseif (in_array($ut, ['guardian', 'parent'], true)) {
                                    $sender_display_name = $this->getGuardianDisplayName($mysqli, $sender_id);
                                } else {
                                    $sender_display_name = $this->getStudentDisplayName($mysqli, $sender_id);
                                }
                            }
                            if ($mysqli) {
                                $mysqli->close();
                            }
                            echo "send_message: receiver_user_id=$receiver_user_id, receiver_user_type=$receiver_user_type\n";
                            @ob_flush(); @flush();

                            $basePayload = [
                                'action' => 'new_message',
                                'message_id' => $message_id,
                                'chat_connection_id' => $chat_connection_id,
                                'chat_user_id' => $effective_receiver_chat_user_id,
                                'message' => $message,
                                'message_type' => $message_type,
                                'sender_id' => $sender_id_for_delivery,
                                'created_at' => date('Y-m-d H:i:s')
                            ];
                            if ($attachment_url !== null && $attachment_url !== '') {
                                $basePayload['image_url'] = $attachment_url;
                                if ($message_type === 'document') {
                                    $basePayload['document_url'] = $attachment_url;
                                }
                            }
                            if ($actual_sender_staff_id !== null) {
                                $basePayload['actual_sender_staff_id'] = $actual_sender_staff_id;
                            }
                            if ($sender_display_name !== null) {
                                $basePayload['sender_display_name'] = $sender_display_name;
                            }

                            // Track staff-side user viewing this chat (for support thread group chat)
                            if ($this->isStaffSideUserType($user_type)) {
                                $this->staffViewingChat[$from] = $chat_connection_id;
                            }

                            // Deliver to the primary receiver (student, teacher, guardian, or Support)
                            $deliveredWs = false;
                            if ($receiver_user_id !== null && (int)$receiver_user_id !== (int) self::SUPPORT_STAFF_ID) {
                                $receiverKeysToTry = $this->getReceiverAppUserIdsForChatUserRow($effective_receiver_chat_user_id);
                                foreach ($receiverKeysToTry as $key) {
                                    if (isset($this->users[$key])) {
                                        try {
                                            $this->users[$key]->send(json_encode($basePayload));
                                            echo "Message delivered via WebSocket to user $key\n";
                                            $deliveredWs = true;
                                            break;
                                        } catch (\Exception $e) {
                                            echo "WebSocket send failed for user $key: {$e->getMessage()}, removing from users\n";
                                            unset($this->users[$key]);
                                        }
                                    }
                                }
                                if (!$deliveredWs) {
                                    echo "Receiver $receiver_user_id not in WebSocket users (tried keys: " . implode(', ', $receiverKeysToTry) . ")\n";
                                }
                            }
                            if (!$deliveredWs && $receiver_user_id !== null && (int)$receiver_user_id === (int) self::SUPPORT_STAFF_ID) {
                                // Receiver is Support: broadcast to all staff (student or teacher may have sent). Skip sender so they don't get duplicate (they already have optimistic message).
                                $staffPayload = $basePayload;
                                $staffPayload['sender_id'] = (string) $sender_id;
                                foreach ($this->staffConnections as $staffConn) {
                                    if ($staffConn === $from) {
                                        continue; // do not send to sender – avoid duplicate on their screen
                                    }
                                    try {
                                        $staffConn->send(json_encode($staffPayload));
                                    } catch (\Exception $e) {
                                        // ignore per-connection errors
                                    }
                                }
                                echo "Message broadcast to staff (Support inbox), sender excluded\n";
                            }

                            // Support thread = group chat: when an admin sends, push to other admins viewing this thread (not to sender = avoid duplicate)
                            if ($admin_replying_as_support) {
                                $staffPayload = $basePayload;
                                $staffPayload['sender_id'] = (string) $sender_id;
                                if ($actual_sender_staff_id !== null) {
                                    $staffPayload['actual_sender_staff_id'] = $actual_sender_staff_id;
                                }
                                if ($sender_display_name !== null) {
                                    $staffPayload['sender_display_name'] = $sender_display_name;
                                }
                                $inThread = 0;
                                foreach ($this->staffConnections as $staffConn) {
                                    if ($staffConn === $from) {
                                        continue; // do not send to sender – they already have optimistic message
                                    }
                                    if (isset($this->staffViewingChat[$staffConn]) && (string)$this->staffViewingChat[$staffConn] === (string)$chat_connection_id) {
                                        try {
                                            $staffConn->send(json_encode($staffPayload));
                                            $inThread++;
                                        } catch (\Exception $e) {
                                            // ignore
                                        }
                                    }
                                }
                                echo "Support thread group: new_message sent to $inThread admin(s) viewing this thread\n";
                            }

                            if (!$deliveredWs && $receiver_user_id && $receiver_user_type && (int)$receiver_user_id !== (int) self::SUPPORT_STAFF_ID) {
                                echo "Sending FCM notification to receiver $receiver_user_id (WebSocket not delivered)...\n";
                                @ob_flush(); @flush();
                                $this->fcmHelper->sendMessageNotification(
                                    $receiver_user_id,
                                    $receiver_user_type,
                                    $sender_id_for_delivery,
                                    $admin_replying_as_support ? 'staff' : $user_type,
                                    $message,
                                    $chat_connection_id,
                                    $effective_receiver_chat_user_id
                                );
                                echo "FCM sendMessageNotification completed for receiver $receiver_user_id\n";
                            } elseif ($receiver_user_id !== null && (int)$receiver_user_id === (int) self::SUPPORT_STAFF_ID) {
                                // Receiver is Support – send FCM to all staff so admins get push when app is closed
                                echo "Sending FCM to all staff (Support inbox)...\n";
                                @ob_flush(); @flush();
                                $this->fcmHelper->sendMessageNotificationToAllStaff(
                                    $sender_id,
                                    $user_type,
                                    $message,
                                    $chat_connection_id,
                                    $sender_chat_user_id
                                );
                            } else {
                                echo "send_message: skip FCM - receiver missing\n";
                            }

                            // Send full new_message to sender so they see their message (app shows only server bubbles)
                            $senderPayload = $basePayload;
                            $senderPayload['sender_id'] = (string) $sender_id;
                            try {
                                $from->send(json_encode($senderPayload));
                            } catch (\Exception $e) {
                                // ignore
                            }

                            $messageSentPayload = [
                                'action' => 'message_sent',
                                'message_id' => $message_id,
                                'status' => 'success'
                            ];
                            if ($sender_display_name !== null) {
                                $messageSentPayload['sender_display_name'] = $sender_display_name;
                            }
                            if ($actual_sender_staff_id !== null) {
                                $messageSentPayload['actual_sender_staff_id'] = $actual_sender_staff_id;
                            }
                            $from->send(json_encode($messageSentPayload));
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
                // Get messages for a chat connection (paginated: last 30 by default, optional before_id for load more)
                $chat_connection_id = $data['chat_connection_id'] ?? null;
                $limit = isset($data['limit']) ? max(1, min(100, intval($data['limit']))) : 30;
                $before_id = isset($data['before_id']) ? intval($data['before_id']) : null;
                if ($chat_connection_id) {
                    // Track which support thread this staff/admin/teacher is viewing (so we can broadcast to all admins in thread)
                    if (isset($from->user_type) && $this->isStaffSideUserType($from->user_type)) {
                        $this->staffViewingChat[$from] = $chat_connection_id;
                    }
                    $current_user_id = isset($from->user_id) ? $from->user_id : null;
                    $current_user_type = isset($from->user_type) ? $from->user_type : 'staff';
                    $result = $this->getMessagesPaginated($chat_connection_id, $current_user_id, $current_user_type, $limit, $before_id);
                    $from->send(json_encode([
                        'action' => 'messages',
                        'chat_connection_id' => $chat_connection_id,
                        'messages' => $result['messages'],
                        'has_more' => $result['has_more']
                    ]));
                }
                break;

            case 'mark_messages_read':
                $chat_connection_id = $data['chat_connection_id'] ?? null;
                $reader_user_id = isset($from->user_id) ? $from->user_id : null;
                $reader_user_type = isset($from->user_type) ? $from->user_type : 'staff';
                if ($chat_connection_id && $reader_user_id !== null) {
                    $this->markMessagesAsRead($chat_connection_id, $reader_user_id, $reader_user_type);
                    $from->send(json_encode(['action' => 'messages_marked_read', 'chat_connection_id' => $chat_connection_id]));

                    // Notify the other party so their sent-message ticks update to "read" in real time
                    $reader_chat_user_id = $this->getChatUserId($reader_user_id, $reader_user_type);
                    if ($reader_chat_user_id) {
                        $other_chat_user_id = $this->getReceiverChatUserId($chat_connection_id, $reader_chat_user_id);
                        if ($other_chat_user_id) {
                            $other_app_user_id = $this->getReceiverAppUserIdByChatUserRowId($other_chat_user_id);
                            $readPayload = json_encode(['action' => 'messages_read', 'chat_connection_id' => $chat_connection_id]);
                            if ($other_app_user_id !== null && (int)$other_app_user_id === (int) self::SUPPORT_STAFF_ID) {
                                // Other party is Support → notify all connected staff/admins
                                foreach ($this->staffConnections as $staffConn) {
                                    if ($staffConn === $from) continue;
                                    try { $staffConn->send($readPayload); } catch (\Exception $e) {}
                                }
                            } else {
                                // Notify individual sender (try all possible connection keys)
                                $keys = $this->getReceiverAppUserIdsForChatUserRow($other_chat_user_id);
                                foreach ($keys as $key) {
                                    if (isset($this->users[$key]) && $this->users[$key] !== $from) {
                                        try { $this->users[$key]->send($readPayload); break; } catch (\Exception $e) {}
                                    }
                                }
                            }
                        }
                    }
                }
                break;

            case 'report_user':
                $reporter_user_id = isset($from->user_id) ? $from->user_id : null;
                $reporter_type = isset($from->user_type) ? $from->user_type : 'staff';
                $reported_user_id = $data['reported_user_id'] ?? null;
                $reported_user_type = isset($data['reported_user_type']) ? $data['reported_user_type'] : 'student';
                $reason = $data['reason'] ?? '';
                $chat_connection_id = isset($data['chat_connection_id']) ? $data['chat_connection_id'] : null;
                $valid_report_types = ['student', 'guardian', 'teacher', 'admin', 'staff'];
                if ($reporter_user_id !== null && $reported_user_id !== null && in_array($reported_user_type, $valid_report_types)) {
                    $ok = $this->saveComplainReport($reporter_user_id, $reporter_type, $reported_user_id, $reported_user_type, $reason, $chat_connection_id);
                    $from->send(json_encode([
                        'action' => $ok ? 'report_submitted' : 'error',
                        'message' => $ok ? 'Report submitted successfully' : 'Failed to submit report'
                    ]));
                } else {
                    $from->send(json_encode(['action' => 'error', 'message' => 'Missing or invalid report data']));
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

                $valid_types = ['student', 'guardian', 'teacher', 'admin', 'staff'];
                if (!in_array($user_type, $valid_types)) {
                    echo "Error: Invalid user_type={$user_type}\n";
                    $from->send(json_encode([
                        'action' => 'error',
                        'message' => 'Invalid user_type. Must be one of: ' . implode(', ', $valid_types)
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
        $user_type = strtolower(trim($mysqli->real_escape_string($user_type)));
        $col = $this->getIdColumnForUserType($user_type);

        // One row per user: update existing row's user_type if present, else insert
        $sql = "UPDATE fl_chat_users SET user_type = '$user_type', updated_at = NOW() WHERE $col = '$user_id'";
        $mysqli->query($sql);
        if ($mysqli->affected_rows > 0) {
            $chat_user_id = $this->getChatUserId($user_id, $user_type);
            $mysqli->close();
            return $chat_user_id;
        }
        $cols = ['staff_id', 'student_id', 'teacher_id', 'parent_id'];
        $vals = ['NULL', 'NULL', 'NULL', 'NULL'];
        foreach ($cols as $i => $c) {
            if ($c === $col) {
                $vals[$i] = "'$user_id'";
                break;
            }
        }
        $sql = "INSERT INTO fl_chat_users (staff_id, student_id, teacher_id, parent_id, user_type, created_at, updated_at)
                VALUES ({$vals[0]}, {$vals[1]}, {$vals[2]}, {$vals[3]}, '$user_type', NOW(), NOW())";

        echo "Executing SQL: {$sql}\n";

        if ($mysqli->query($sql)) {
            echo "✓ SQL query executed successfully\n";
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
        if (isset($this->staffViewingChat[$conn])) {
            $this->staffViewingChat->detach($conn);
        }

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
     * Admin display name from staff table (column: name)
     */
    private function getStaffDisplayName($mysqli, $staff_id)
    {
        if (!$mysqli || $staff_id === null) {
            return null;
        }
        $id = $mysqli->real_escape_string($staff_id);
        $res = $mysqli->query("SELECT name FROM staff WHERE id = '$id' LIMIT 1");
        if ($res) {
            $row = $res->fetch_assoc();
            if ($row && !empty($row['name'])) {
                return $row['name'];
            }
        }
        return null;
    }

    /**
     * Format student display name from students table: firstname, lastname, admission_no
     */
    private function formatStudentDisplayName($firstname, $lastname, $admission_no)
    {
        $parts = array_filter([trim((string)$firstname), trim((string)$lastname)]);
        $name = implode(' ', $parts);
        if ($name === '') {
            return null;
        }
        $admission = trim((string)$admission_no);
        if ($admission !== '') {
            $name .= ' (' . $admission . ')';
        }
        return $name;
    }

    /**
     * Student display name from students table (user_id = fl_chat_users.student_id)
     */
    private function getStudentDisplayName($mysqli, $student_id)
    {
        if (!$mysqli || $student_id === null) {
            return null;
        }
        $id = $mysqli->real_escape_string($student_id);
        $res = $mysqli->query("SELECT firstname, lastname, admission_no FROM students WHERE id = '$id' LIMIT 1");
        if ($res && $row = $res->fetch_assoc()) {
            return $this->formatStudentDisplayName($row['firstname'] ?? null, $row['lastname'] ?? null, $row['admission_no'] ?? null);
        }
        return null;
    }

    /**
     * Guardian/parent display name (students.guardian_name; parent_id may reference students.id)
     */
    private function getGuardianDisplayName($mysqli, $parent_id)
    {
        if (!$mysqli || $parent_id === null) {
            return null;
        }
        $id = $mysqli->real_escape_string($parent_id);
        $res = $mysqli->query("SELECT guardian_name FROM students WHERE id = '$id' LIMIT 1");
        if ($res && $row = $res->fetch_assoc() && !empty(trim((string)($row['guardian_name'] ?? '')))) {
            return trim($row['guardian_name']);
        }
        return null;
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
            'localhost',
            'portal_beta',
            'X7&?C%Yx5[L-QyiL',
            'portal_beta'
        );

        if ($mysqli->connect_error) {
            return null;
        }

        return $mysqli;
    }

    /**
     * Check if a table has a column (for optional schema columns)
     */
    private function hasColumn($mysqli, $table, $column)
    {
        $table = $mysqli->real_escape_string($table);
        $column = $mysqli->real_escape_string($column);
        $res = $mysqli->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
        return $res && $res->num_rows > 0;
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
        $actual_sender_staff_id = isset($data['actual_sender_staff_id']) ? intval($data['actual_sender_staff_id']) : null;
        $message_type = isset($data['message_type']) ? $mysqli->real_escape_string(trim($data['message_type'])) : 'text';
        if (!in_array($message_type, ['text', 'image', 'document'])) {
            $message_type = 'text';
        }
        $image_url = isset($data['image_url']) && $data['image_url'] !== '' ? $mysqli->real_escape_string($data['image_url']) : null;
        if ($image_url === null && isset($data['document_url']) && $data['document_url'] !== '') {
            $image_url = $mysqli->real_escape_string($data['document_url']);
        }

        $cols = "chat_connection_id, chat_user_id, message, ip, time, created_at, is_read";
        $vals = "'$chat_connection_id', '$chat_user_id', '$message', '$ip', $time, '$created_at', 0";
        if ($actual_sender_staff_id !== null) {
            $cols .= ", actual_sender_staff_id";
            $vals .= ", " . $actual_sender_staff_id;
        }
        // message_type and image_url if table has these columns (run add_message_type_and_image_url.sql)
        if ($this->hasColumn($mysqli, 'fl_chat_messages', 'message_type')) {
            $cols .= ", message_type";
            $vals .= ", '" . $mysqli->real_escape_string($message_type) . "'";
        }
        if ($image_url !== null && $this->hasColumn($mysqli, 'fl_chat_messages', 'image_url')) {
            $cols .= ", image_url";
            $vals .= ", '" . $image_url . "'";
        }
        $sql = "INSERT INTO fl_chat_messages ($cols) VALUES ($vals)";

        if ($mysqli->query($sql)) {
            $message_id = $mysqli->insert_id;
            $mysqli->close();
            return $message_id;
        }

        $mysqli->close();
        return false;
    }

    /**
     * Whether user_type is admin-side (actual admin/staff only).
     * Teachers are intentionally excluded: they use Support chat as a requester, not as a replier.
     */
    private function isStaffSideUserType($user_type)
    {
        $t = strtolower(trim((string) $user_type));
        return in_array($t, ['staff', 'admin'], true);
    }

    /**
     * Whether user_type is the requesting/user side of Support chat (student, guardian, teacher).
     * These users can only chat with Support, not reply on behalf of Support.
     */
    private function isStudentSideUserType($user_type)
    {
        $t = strtolower(trim((string) $user_type));
        return in_array($t, ['student', 'guardian', 'teacher'], true);
    }

    /**
     * Get chat_user_id by the ID column for this user_type.
     * Uses fallback for legacy rows: teacher can be in teacher_id or staff_id; guardian in parent_id or student_id.
     */
    private function getChatUserId($user_id, $user_type = 'staff')
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }

        $user_id = $mysqli->real_escape_string($user_id);
        $user_type = strtolower(trim($mysqli->real_escape_string($user_type)));

        $col = $this->getIdColumnForUserType($user_type);
        $sql = "SELECT id FROM fl_chat_users WHERE $col = '$user_id' LIMIT 1";
        $result = $mysqli->query($sql);
        if ($result && $row = $result->fetch_assoc()) {
            $mysqli->close();
            return intval($row['id']);
        }

        // Fallback for legacy rows: teacher stored with staff_id, guardian with student_id
        if ($user_type === 'teacher') {
            $sql = "SELECT id FROM fl_chat_users WHERE staff_id = '$user_id' AND user_type = 'teacher' LIMIT 1";
            $result = $mysqli->query($sql);
            if ($result && $row = $result->fetch_assoc()) {
                $mysqli->close();
                return intval($row['id']);
            }
        }
        if (in_array($user_type, ['guardian', 'parent'], true)) {
            $sql = "SELECT id FROM fl_chat_users WHERE student_id = '$user_id' AND user_type IN ('guardian', 'parent') LIMIT 1";
            $result = $mysqli->query($sql);
            if ($result && $row = $result->fetch_assoc()) {
                $mysqli->close();
                return intval($row['id']);
            }
        }

        $mysqli->close();
        return null;
    }

    /** Which fl_chat_users column holds the user id for this user_type (staff_id, student_id, teacher_id, parent_id). */
    private function getIdColumnForUserType($user_type)
    {
        $t = strtolower(trim((string) $user_type));
        if (in_array($t, ['staff', 'admin'], true)) {
            return 'staff_id';
        }
        if ($t === 'teacher') {
            return 'teacher_id';
        }
        if (in_array($t, ['guardian', 'parent'], true)) {
            return 'parent_id';
        }
        return 'student_id';
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
     * Get receiver's app user_id (staff_id, student_id, teacher_id, or parent_id) from fl_chat_users row id.
     * Uses the column that matches user_type so FCM lookup (getFCMTokenForChatUserId) and WebSocket delivery
     * work correctly for teacher, student, guardian, and admin in support and direct chats.
     *
     * @param int|string $receiver_chat_user_row_id fl_chat_users.id (row primary key) for the receiver
     * @return string|null Receiver's app uid or null
     */
    private function getReceiverAppUserIdByChatUserRowId($receiver_chat_user_row_id)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }
        $row_id = $mysqli->real_escape_string((string) $receiver_chat_user_row_id);
        $sql = "SELECT staff_id, student_id, teacher_id, parent_id, user_type FROM fl_chat_users WHERE id = '$row_id' LIMIT 1";
        $result = $mysqli->query($sql);
        if ($result && ($row = $result->fetch_assoc())) {
            $user_type = isset($row['user_type']) ? strtolower(trim((string) $row['user_type'])) : '';
            $col = $this->getIdColumnForUserType($user_type);
            $user_id = null;
            // For the Support virtual user (staff_id=0, user_type='staff') we must return '0' so the
            // caller can detect it as Support and broadcast to all admins.
            if ($col === 'staff_id' && $row['staff_id'] !== null && $row['staff_id'] !== '') {
                $user_id = $row['staff_id']; // includes '0' for Support virtual user
            } elseif ($col === 'teacher_id' && $row['teacher_id'] !== null && $row['teacher_id'] !== '' && (string)$row['teacher_id'] !== '0') {
                $user_id = $row['teacher_id'];
            } elseif ($col === 'student_id' && $row['student_id'] !== null && $row['student_id'] !== '' && (string)$row['student_id'] !== '0') {
                $user_id = $row['student_id'];
            } elseif ($col === 'parent_id' && $row['parent_id'] !== null && $row['parent_id'] !== '' && (string)$row['parent_id'] !== '0') {
                $user_id = $row['parent_id'];
            }
            // Fallback: legacy rows or empty user_type – use first non-null id column (exclude 0 for non-staff)
            if ($user_id === null || $user_id === '') {
                $user_id = ($row['staff_id'] !== null && $row['staff_id'] !== '') ? $row['staff_id']
                    : (($row['student_id'] !== null && $row['student_id'] !== '' && (string)$row['student_id'] !== '0') ? $row['student_id']
                    : (($row['teacher_id'] !== null && $row['teacher_id'] !== '' && (string)$row['teacher_id'] !== '0') ? $row['teacher_id']
                    : $row['parent_id']));
            }
            $mysqli->close();
            return $user_id !== null && $user_id !== '' ? (string) $user_id : null;
        }
        $mysqli->close();
        return null;
    }

    /**
     * Get all possible app user ids for a chat_user row (for WebSocket delivery).
     * Returns the canonical id first (matching user_type), then any other set ids so we can try
     * alternative keys when the client connected with a different id (e.g. teacher with staff_id).
     *
     * @param int|string $chat_user_row_id fl_chat_users.id
     * @return array List of string ids to try (e.g. ['5'] or ['5', '5'] for teacher with staff_id=5, teacher_id=5)
     */
    private function getReceiverAppUserIdsForChatUserRow($chat_user_row_id)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return [];
        }
        $row_id = $mysqli->real_escape_string((string) $chat_user_row_id);
        $sql = "SELECT staff_id, student_id, teacher_id, parent_id, user_type FROM fl_chat_users WHERE id = '$row_id' LIMIT 1";
        $result = $mysqli->query($sql);
        if (!$result || !$row = $result->fetch_assoc()) {
            $mysqli->close();
            return [];
        }
        $user_type = isset($row['user_type']) ? strtolower(trim((string) $row['user_type'])) : '';
        $col = $this->getIdColumnForUserType($user_type);
        $ids = [];
        $add = function ($val) use (&$ids) {
            if ($val !== null && $val !== '' && (string)$val !== '0') {
                $k = (string) $val;
                if (!in_array($k, $ids, true)) {
                    $ids[] = $k;
                }
            }
        };
        // Add canonical id first
        if ($col === 'staff_id') {
            $add($row['staff_id']);
        } elseif ($col === 'teacher_id') {
            $add($row['teacher_id']);
        } elseif ($col === 'student_id') {
            $add($row['student_id']);
        } else {
            $add($row['parent_id']);
        }
        // Add other set ids so we try alternative connection keys
        $add($row['staff_id']);
        $add($row['student_id']);
        $add($row['teacher_id']);
        $add($row['parent_id']);
        $mysqli->close();
        return $ids;
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
     * Get messages for a chat connection with sender information (paginated)
     * Returns last $limit messages (newest first in DB order); optional $before_id for "load more" (older messages).
     * Returns ['messages' => array, 'has_more' => bool].
     */
    private function getMessagesPaginated($chat_connection_id, $current_user_id = null, $current_user_type = 'staff', $limit = 30, $before_id = null)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return ['messages' => [], 'has_more' => false];
        }

        $chat_connection_id = $mysqli->real_escape_string($chat_connection_id);
        $limit = max(1, min(100, intval($limit)));
        $fetch = $limit + 1; // fetch one extra to know if there are more

        $conn_sql = "SELECT chat_user_one, chat_user_two FROM fl_chat_connections WHERE id = '$chat_connection_id' LIMIT 1";
        $conn_result = $mysqli->query($conn_sql);
        if (!$conn_result || !($conn_row = $conn_result->fetch_assoc())) {
            $mysqli->close();
            return ['messages' => [], 'has_more' => false];
        }

        $chat_user_one_id = intval($conn_row['chat_user_one']);
        $chat_user_two_id = intval($conn_row['chat_user_two']);

        $where = "m.chat_connection_id = '$chat_connection_id'";
        if ($before_id !== null && $before_id > 0) {
            $before_id = intval($before_id);
            $where .= " AND m.id < $before_id";
        }

        $sql = "SELECT m.*, 
                       cu1.staff_id as user_one_staff_id, cu1.student_id as user_one_student_id, cu1.teacher_id as user_one_teacher_id, cu1.parent_id as user_one_parent_id,
                       cu2.staff_id as user_two_staff_id, cu2.student_id as user_two_student_id, cu2.teacher_id as user_two_teacher_id, cu2.parent_id as user_two_parent_id,
                       actual_staff.name as actual_sender_display_name,
                       s1.name as user_one_staff_name, s2.name as user_two_staff_name,
                       ts1.name as user_one_teacher_name, ts2.name as user_two_teacher_name,
                       st1.firstname as user_one_firstname, st1.lastname as user_one_lastname, st1.admission_no as user_one_admission_no,
                       st2.firstname as user_two_firstname, st2.lastname as user_two_lastname, st2.admission_no as user_two_admission_no
                FROM fl_chat_messages m
                LEFT JOIN fl_chat_users cu1 ON cu1.id = '$chat_user_one_id'
                LEFT JOIN fl_chat_users cu2 ON cu2.id = '$chat_user_two_id'
                LEFT JOIN staff actual_staff ON actual_staff.id = m.actual_sender_staff_id
                LEFT JOIN staff s1 ON s1.id = cu1.staff_id
                LEFT JOIN staff s2 ON s2.id = cu2.staff_id
                LEFT JOIN staff ts1 ON ts1.id = cu1.teacher_id
                LEFT JOIN staff ts2 ON ts2.id = cu2.teacher_id
                LEFT JOIN users u1 ON u1.user_id = cu1.student_id
                LEFT JOIN users u2 ON u2.user_id = cu2.student_id
                LEFT JOIN students st1 ON st1.id = u1.user_id
                LEFT JOIN students st2 ON st2.id = u2.user_id
                WHERE $where 
                ORDER BY m.created_at DESC, m.id DESC 
                LIMIT $fetch";

        $result = $mysqli->query($sql);
        $messages = [];
        $has_more = false;

        if ($result) {
            $rows = [];
            while ($row = $result->fetch_assoc()) {
                $rows[] = $row;
            }
            if (count($rows) > $limit) {
                $has_more = true;
                array_pop($rows);
            }
            foreach ($rows as $row) {
                $receiver_chat_user_id = intval($row['chat_user_id']);
                $sender_chat_user_id = ($receiver_chat_user_id == $chat_user_one_id) ? $chat_user_two_id : $chat_user_one_id;
                $sender_id = null;
                if ($sender_chat_user_id == $chat_user_one_id) {
                    $sender_id = $row['user_one_staff_id'] ?? $row['user_one_student_id'] ?? $row['user_one_teacher_id'] ?? $row['user_one_parent_id'];
                } else {
                    $sender_id = $row['user_two_staff_id'] ?? $row['user_two_student_id'] ?? $row['user_two_teacher_id'] ?? $row['user_two_parent_id'];
                }
                if ($sender_id !== null) {
                    $sender_id = (string) $sender_id;
                }
                $actual_sender_staff_id = isset($row['actual_sender_staff_id']) ? $row['actual_sender_staff_id'] : null;
                $sender_display_name = null;
                if ($actual_sender_staff_id !== null && !empty($row['actual_sender_display_name'])) {
                    $sender_display_name = $row['actual_sender_display_name'];
                } elseif ($sender_chat_user_id == $chat_user_one_id) {
                    $sender_display_name = !empty($row['user_one_staff_name']) ? $row['user_one_staff_name'] : (!empty($row['user_one_teacher_name']) ? $row['user_one_teacher_name'] : $this->formatStudentDisplayName($row['user_one_firstname'] ?? null, $row['user_one_lastname'] ?? null, $row['user_one_admission_no'] ?? null));
                } else {
                    $sender_display_name = !empty($row['user_two_staff_name']) ? $row['user_two_staff_name'] : (!empty($row['user_two_teacher_name']) ? $row['user_two_teacher_name'] : $this->formatStudentDisplayName($row['user_two_firstname'] ?? null, $row['user_two_lastname'] ?? null, $row['user_two_admission_no'] ?? null));
                }
                $message = [
                    'id' => $row['id'],
                    'chat_connection_id' => $row['chat_connection_id'],
                    'chat_user_id' => $row['chat_user_id'],
                    'message' => $row['message'],
                    'ip' => $row['ip'],
                    'time' => $row['time'],
                    'is_read' => $row['is_read'],
                    'created_at' => $row['created_at'],
                    'sender_id' => $sender_id ? (string)$sender_id : null,
                    'actual_sender_staff_id' => $actual_sender_staff_id !== null ? (string)$actual_sender_staff_id : null,
                    'sender_display_name' => $sender_display_name,
                    'message_type' => isset($row['message_type']) && in_array($row['message_type'], ['text', 'image', 'document']) ? $row['message_type'] : 'text',
                    'image_url' => isset($row['image_url']) && $row['image_url'] !== '' && $row['image_url'] !== null ? $row['image_url'] : null,
                ];
                $messages[] = $message;
            }
        }

        $mysqli->close();
        return ['messages' => $messages, 'has_more' => $has_more];
    }

    /**
     * Mark messages in a chat as read (messages sent TO the current user in this connection)
     */
    private function markMessagesAsRead($chat_connection_id, $reader_user_id, $reader_user_type)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return;
        }
        $chat_connection_id = $mysqli->real_escape_string($chat_connection_id);
        $reader_chat_user_id = $this->getChatUserId($reader_user_id, $reader_user_type);
        if ($reader_chat_user_id === null) {
            $mysqli->close();
            return;
        }
        $reader_chat_user_id = intval($reader_chat_user_id);
        $mysqli->query("UPDATE fl_chat_messages SET is_read = 1 WHERE chat_connection_id = '$chat_connection_id' AND chat_user_id = $reader_chat_user_id");
        $mysqli->close();
    }

    /**
     * Save a complaint report to complain_reports table
     */
    private function saveComplainReport($reporter_user_id, $reporter_type, $reported_user_id, $reported_user_type, $reason, $chat_connection_id = null)
    {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return false;
        }
        $reporter_user_id = $mysqli->real_escape_string($reporter_user_id);
        $reporter_type = $mysqli->real_escape_string($reporter_type);
        $reported_user_id = $mysqli->real_escape_string($reported_user_id);
        $reported_user_type = $mysqli->real_escape_string($reported_user_type);
        $reason = $mysqli->real_escape_string($reason);
        $chat_connection_id = $chat_connection_id !== null ? intval($chat_connection_id) : 'NULL';
        $chat_sql = $chat_connection_id === 'NULL' ? 'NULL' : "'$chat_connection_id'";
        $sql = "INSERT INTO complain_reports (reporter_user_id, reporter_type, reported_user_id, reported_user_type, chat_connection_id, reason, status) 
                VALUES ('$reporter_user_id', '$reporter_type', '$reported_user_id', '$reported_user_type', $chat_sql, '$reason', 'pending')";
        $ok = $mysqli->query($sql);
        $mysqli->close();
        return (bool) $ok;
    }

    /**
     * Check for pending notice broadcast file (written by CodeIgniter when a new notice is added)
     * and broadcast new_notice to connected clients. For student user_type only: when the notice
     * has class_id and section_id, only students in that class/section receive the broadcast.
     * Clients should refresh their full notice list (get_send_notifications) and unread list
     * (get_unread_notifications) when they receive this so the dashboard notice box updates in real time.
     */
    public function checkAndBroadcastNewNotice()
    {
        $path = $this->pendingNoticeBroadcastPath;
        if (!file_exists($path)) {
            return;
        }
        $json = @file_get_contents($path);
        if ($json === false || $json === '') {
            return;
        }
        $data = json_decode($json, true);
        if (!is_array($data)) {
            @unlink($path);
            return;
        }
        $payload = [
            'action' => 'new_notice',
            'notice' => $data,
            'refresh_unread' => true,
        ];
        $message = json_encode($payload);

        $visible_student = isset($data['visible_student']) && in_array(strtolower($data['visible_student']), ['yes', 'y'], true);
        $visible_staff   = isset($data['visible_staff']) && in_array(strtolower($data['visible_staff']), ['yes', 'y'], true);
        $visible_parent  = isset($data['visible_parent']) && in_array(strtolower($data['visible_parent']), ['yes', 'y'], true);
        $class_id        = isset($data['class_id']) && $data['class_id'] !== '' && $data['class_id'] !== null ? (int) $data['class_id'] : null;
        $section_id      = isset($data['section_id']) && $data['section_id'] !== '' && $data['section_id'] !== null ? (int) $data['section_id'] : null;

        $allowed_student_ids = null;
        if ($visible_student && $class_id !== null && $section_id !== null) {
            $mysqli = $this->getDbConnection();
            if ($mysqli) {
                $res = $mysqli->query("SELECT session_id FROM student_session ORDER BY session_id DESC LIMIT 1");
                if ($res && $row = $res->fetch_assoc() && !empty($row['session_id'])) {
                    $session_id = $mysqli->real_escape_string($row['session_id']);
                    $class_id   = (int) $class_id;
                    $section_id = (int) $section_id;
                    $res2 = $mysqli->query("SELECT student_id FROM student_session WHERE session_id = '" . $session_id . "' AND class_id = " . $class_id . " AND section_id = " . $section_id);
                    $allowed_student_ids = [];
                    if ($res2) {
                        while ($r = $res2->fetch_assoc()) {
                            $allowed_student_ids[(string) $r['student_id']] = true;
                        }
                    }
                }
                $mysqli->close();
            }
        }

        $count = 0;
        foreach ($this->clients as $client) {
            $user_id   = isset($client->user_id) ? $client->user_id : null;
            $user_type = isset($client->user_type) ? $client->user_type : null;

            if ($user_id === null || $user_type === null) {
                continue;
            }

            $send = false;
            if ($user_type === 'staff' && $visible_staff) {
                $send = true;
            } elseif ($user_type === 'student' && $visible_student) {
                if ($allowed_student_ids === null) {
                    $send = true;
                } elseif (isset($allowed_student_ids[(string) $user_id])) {
                    $send = true;
                }
            } elseif ($user_type === 'parent' && $visible_parent) {
                $send = true;
            }

            if ($send) {
                try {
                    $client->send($message);
                    $count++;
                } catch (\Exception $e) {
                    echo "Broadcast new_notice to client failed: " . $e->getMessage() . "\n";
                }
            }
        }
        echo "Broadcast new_notice to {$count} client(s)\n";
        @unlink($path);
    }
}

// Start the server with event loop so we can poll for pending notice broadcasts
$port = 8080; // WebSocket port
$address = '0.0.0.0';

$loop = \React\EventLoop\Factory::create();
$app = new ChatWebSocketServer();
$socket = new \React\Socket\Server($address . ':' . $port, $loop);
$server = new IoServer(
    new HttpServer(new WsServer($app)),
    $socket,
    $loop
);

// Poll every 3 seconds for new notice broadcast (triggered when admin adds a notice)
$loop->addPeriodicTimer(3, function () use ($app) {
    $app->checkAndBroadcastNewNotice();
});

echo "WebSocket server started on port {$port}\n";
echo "Connect to: ws://localhost:{$port}\n";
$loop->run();


//retrieve lists from REST and use websocket to only listen data changes