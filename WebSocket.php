<?php

if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}

/**
 * WebSocket Controller for Real-time Chat
 * 
 * This controller provides API endpoints for the Flutter app to:
 * - Send messages (which will be broadcast via WebSocket)
 * - Get messages for a chat connection
 * - Handle WebSocket connections
 */
class WebSocket extends CI_Controller
{
    public function __construct()
    {
        parent::__construct();
        
        // Skip authentication for API endpoints
        // This prevents CodeIgniter from redirecting to login page
        $method = $this->router->method;
        $api_methods = ['create_chat_user', 'health', 'get_messages', 'get_connections'];
        
        if (in_array($method, $api_methods)) {
            // Set JSON header early to prevent HTML redirects
            header('Content-Type: application/json');
            
            // Try to prevent authentication redirects by setting this before parent::__construct()
            // Note: If your CodeIgniter has global authentication hooks, you may need to
            // modify the hooks configuration to exclude this controller or these methods
        }
        
        $this->load->model('Chatuser_model');
        $this->load->model('DirectMessage_model');
        $this->load->library('enc_lib');
    }

    /**
     * API endpoint for Flutter app to send messages
     * POST: /websocket/send_message
     * 
     * Expected POST data:
     * - chat_connection_id: ID of the chat connection
     * - chat_user_id: ID of the user receiving the message
     * - message: The message text
     * - sender_id: ID of the user sending the message
     */
    public function send_message()
    {
        // Set JSON response header
        header('Content-Type: application/json');

        // Get POST data
        $chat_connection_id = $this->input->post('chat_connection_id');
        $chat_user_id = $this->input->post('chat_user_id');
        $message = $this->input->post('message');
        $sender_id = $this->input->post('sender_id');

        // Validate required fields
        if (empty($chat_connection_id) || empty($chat_user_id) || empty($message) || empty($sender_id)) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Missing required fields: chat_connection_id, chat_user_id, message, sender_id'
            ]);
            return;
        }

        // Prepare message data
        $insert_record = array(
            'chat_user_id' => $chat_user_id,
            'message' => trim($message),
            'chat_connection_id' => $chat_connection_id,
            'created_at' => date('Y-m-d H:i:s'),
            'is_read' => 0
        );

        // Save message to database
        $last_insert_id = $this->chatuser_model->addMessage($this->security->xss_clean($insert_record));

        if ($last_insert_id) {
            // Broadcast message via WebSocket
            $this->broadcastMessage([
                'action' => 'new_message',
                'message_id' => $last_insert_id,
                'chat_connection_id' => $chat_connection_id,
                'chat_user_id' => $chat_user_id,
                'message' => $message,
                'sender_id' => $sender_id,
                'created_at' => $insert_record['created_at']
            ], $chat_connection_id, $sender_id);

            echo json_encode([
                'status' => 'success',
                'message_id' => $last_insert_id,
                'message' => 'Message sent successfully'
            ]);
        } else {
            echo json_encode([
                'status' => 'error',
                'message' => 'Failed to save message'
            ]);
        }
    }

    /**
     * API endpoint to get messages for a chat connection
     * GET: /websocket/get_messages/{chat_connection_id}
     */
    public function get_messages($chat_connection_id = null)
    {
        header('Content-Type: application/json');

        if (empty($chat_connection_id)) {
            $chat_connection_id = $this->input->get('chat_connection_id');
        }

        if (empty($chat_connection_id)) {
            echo json_encode([
                'status' => 'error',
                'message' => 'chat_connection_id is required'
            ]);
            return;
        }

        // Get messages from database
        $messages = $this->chatuser_model->myChatAndUpdate($chat_connection_id, null);

        echo json_encode([
            'status' => 'success',
            'chat_connection_id' => $chat_connection_id,
            'messages' => $messages
        ]);
    }

    /**
     * Broadcast message to WebSocket server
     * This sends the message to the WebSocket server which will then
     * broadcast it to connected clients
     */
    private function broadcastMessage($message_data, $chat_connection_id, $sender_id)
    {
        // Get receiver user_id from chat_connection
        $chat_connection = $this->chatuser_model->getChatConnectionByID($chat_connection_id);
        
        if (!$chat_connection) {
            return false;
        }

        // Determine receiver_id
        $receiver_id = ($chat_connection->chat_user_one == $sender_id) 
            ? $chat_connection->chat_user_two 
            : $chat_connection->chat_user_one;

        // Send to WebSocket server
        $ws_url = 'ws://localhost:8080';
        $message_json = json_encode($message_data);

        // Use cURL to send message to WebSocket server
        // Note: In production, you might want to use a message queue (Redis, RabbitMQ)
        // or directly use the WebSocket server's internal methods
        
        // For now, we'll save the message and the WebSocket server will handle broadcasting
        // when clients request updates or when polling
        
        return true;
    }

    /**
     * API endpoint to get chat connections for a user
     * GET: /websocket/get_connections
     * 
     * Query params:
     * - user_id: The user ID
     * - user_type: 'staff' or 'student'
     */
    public function get_connections()
    {
        header('Content-Type: application/json');

        $user_id = $this->input->get('user_id');
        $user_type = $this->input->get('user_type') ?: 'staff';

        if (empty($user_id)) {
            echo json_encode([
                'status' => 'error',
                'message' => 'user_id is required'
            ]);
            return;
        }

        // Get chat user ID
        $chat_user = $this->chatuser_model->getMyID($user_id, $user_type);

        if (empty($chat_user)) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Chat user not found'
            ]);
            return;
        }

        // Get connections
        $connections = $this->chatuser_model->myUser($user_id, $chat_user->id, $user_type);

        echo json_encode([
            'status' => 'success',
            'connections' => json_decode($connections)
        ]);
    }

    /**
     * API endpoint to create or get chat user
     * POST: /websocket/create_chat_user
     * 
     * Expected POST data:
     * - user_id: The staff_id or student_id
     * - user_type: 'staff' or 'student' (default: 'staff')
     * 
     * Returns:
     * - status: 'success' or 'error'
     * - chat_user_id: The ID of the chat user
     * - is_new: true if newly created, false if already existed
     * - message: Success or error message
     */
    public function create_chat_user()
    {
        // Set JSON header immediately and prevent any output buffering issues
        header('Content-Type: application/json');
        
        // Clear any previous output that might have been sent (like redirects)
        if (ob_get_level()) {
            ob_clean();
        }
        
        // Prevent CodeIgniter from sending any additional headers or redirects
        $this->output->set_content_type('application/json');

        // Get POST data
        $user_id_raw = $this->input->post('user_id');
        $user_type = $this->input->post('user_type') ? trim($this->input->post('user_type')) : 'staff';

        // Handle both string and integer user_id
        $user_id = $user_id_raw !== null ? intval($user_id_raw) : null;

        // Validate required fields
        if (!$user_id) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Missing user_id'
            ]);
            return;
        }

        // Validate user_type
        if (!in_array($user_type, ['staff', 'student'])) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Invalid user_type. Must be "staff" or "student"'
            ]);
            return;
        }

        // Check if chat user already exists
        $chat_user_id = $this->DirectMessage_model->getChatUserId($user_id, $user_type);
        $is_new = false;

        if (!$chat_user_id) {
            // Create new chat user entry
            $chat_user_id = $this->DirectMessage_model->createChatUser($user_id, $user_type);
            $is_new = true;
        }

        if ($chat_user_id) {
            $response = [
                'status' => 'success',
                'chat_user_id' => $chat_user_id,
                'is_new' => $is_new,
                'message' => $is_new ? 'Chat user created successfully' : 'Chat user already exists'
            ];
            $this->output->set_output(json_encode($response));
            $this->output->_display();
            exit; // Prevent any further output
        } else {
            $response = [
                'status' => 'error',
                'message' => 'Failed to create chat user entry. Check database connection and table structure.'
            ];
            $this->output->set_output(json_encode($response));
            $this->output->_display();
            exit; // Prevent any further output
        }
    }

    /**
     * Health check endpoint
     * GET: /websocket/health
     */
    public function health()
    {
        header('Content-Type: application/json');
        echo json_encode([
            'status' => 'ok',
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
}
