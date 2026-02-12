<?php
/**
 * FCM Notification Helper for WebSocket Server (FCM API v1)
 * 
 * This helper class sends FCM push notifications using the v1 API when messages are received
 * and the recipient is not connected via WebSocket (app is closed/backgrounded)
 * 
 * Requires: Firebase service account JSON file
 */

class FCMNotificationHelper {
    private $projectId;
    private $serviceAccountPath;
    private $accessToken;
    private $accessTokenExpiry;
    
    public function __construct($serviceAccountPath = null, $projectId = null) {
        // Get service account path and project ID from configuration
        $this->serviceAccountPath = $serviceAccountPath ?? $this->getServiceAccountPath();
        $this->projectId = $projectId ?? $this->getProjectId();
    }
    
    /**
     * Get service account JSON file path from configuration
     */
    private function getServiceAccountPath() {
        // Try to get from environment variable
        if (getenv('FCM_SERVICE_ACCOUNT_PATH')) {
            return getenv('FCM_SERVICE_ACCOUNT_PATH');
        }
        
        // Try to get from CodeIgniter config
        if (file_exists(__DIR__ . '/application/config/fcm.php')) {
            require __DIR__ . '/application/config/fcm.php';
            if (isset($config['service_account_path'])) {
                return $config['service_account_path'];
            }
        }
        
        // Try to get from database config table
        $mysqli = $this->getDbConnection();
        if ($mysqli) {
            $result = $mysqli->query("SELECT value FROM fl_config WHERE key_name = 'fcm_service_account_path' LIMIT 1");
            if ($result && $row = $result->fetch_assoc()) {
                $path = $row['value'];
                $mysqli->close();
                return $path;
            }
            $mysqli->close();
        }
        
        // Default path
        $defaultPath = __DIR__ . '/firebase-service-account.json';
        if (file_exists($defaultPath)) {
            return $defaultPath;
        }
        
        return null;
    }
    
    /**
     * Get project ID from configuration or service account file
     */
    private function getProjectId() {
        // Try to get from environment variable
        if (getenv('FCM_PROJECT_ID')) {
            return getenv('FCM_PROJECT_ID');
        }
        
        // Try to get from CodeIgniter config
        if (file_exists(__DIR__ . '/application/config/fcm.php')) {
            require __DIR__ . '/application/config/fcm.php';
            if (isset($config['project_id'])) {
                return $config['project_id'];
            }
        }
        
        // Try to get from database config table
        $mysqli = $this->getDbConnection();
        if ($mysqli) {
            $result = $mysqli->query("SELECT value FROM fl_config WHERE key_name = 'fcm_project_id' LIMIT 1");
            if ($result && $row = $result->fetch_assoc()) {
                $projectId = $row['value'];
                $mysqli->close();
                return $projectId;
            }
            $mysqli->close();
        }
        
        // Try to get from service account file
        if ($this->serviceAccountPath && file_exists($this->serviceAccountPath)) {
            $serviceAccount = json_decode(file_get_contents($this->serviceAccountPath), true);
            if (isset($serviceAccount['project_id'])) {
                return $serviceAccount['project_id'];
            }
        }
        
        return null;
    }
    
    /**
     * Get database connection (reuse from WebSocket server)
     */
    private function getDbConnection() {
        if (!defined('BASEPATH')) {
            define('BASEPATH', __DIR__ . '/system/');
        }
        if (!defined('ENVIRONMENT')) {
            define('ENVIRONMENT', 'production');
        }
        
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
     * Get OAuth 2.0 access token using service account
     */
    private function getAccessToken() {
        // Return cached token if still valid
        if ($this->accessToken && $this->accessTokenExpiry && time() < $this->accessTokenExpiry) {
            return $this->accessToken;
        }
        
        if (empty($this->serviceAccountPath) || !file_exists($this->serviceAccountPath)) {
            echo "FCM: Service account file not found at: {$this->serviceAccountPath}\n";
            return null;
        }
        
        $serviceAccount = json_decode(file_get_contents($this->serviceAccountPath), true);
        
        if (!isset($serviceAccount['private_key']) || !isset($serviceAccount['client_email'])) {
            echo "FCM: Invalid service account file. Missing private_key or client_email.\n";
            return null;
        }
        
        // Create JWT for OAuth 2.0
        $now = time();
        $jwt = $this->createJWT($serviceAccount, $now);
        
        // Exchange JWT for access token
        $tokenUrl = 'https://oauth2.googleapis.com/token';
        $tokenData = [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt
        ];
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $tokenUrl);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($tokenData));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode != 200) {
            echo "FCM: Failed to get access token. HTTP Code: $httpCode, Response: $response\n";
            return null;
        }
        
        $tokenData = json_decode($response, true);
        if (!isset($tokenData['access_token'])) {
            echo "FCM: Invalid token response: $response\n";
            return null;
        }
        
        // Cache token (expires in 1 hour, but we'll refresh 5 minutes early)
        $this->accessToken = $tokenData['access_token'];
        $this->accessTokenExpiry = $now + ($tokenData['expires_in'] ?? 3600) - 300;
        
        return $this->accessToken;
    }
    
    /**
     * Create JWT for OAuth 2.0 authentication
     */
    private function createJWT($serviceAccount, $now) {
        $header = [
            'alg' => 'RS256',
            'typ' => 'JWT'
        ];
        
        $claim = [
            'iss' => $serviceAccount['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'exp' => $now + 3600,
            'iat' => $now
        ];
        
        $headerEncoded = $this->base64UrlEncode(json_encode($header));
        $claimEncoded = $this->base64UrlEncode(json_encode($claim));
        
        $signatureInput = $headerEncoded . '.' . $claimEncoded;
        
        // Sign with private key
        $privateKey = openssl_pkey_get_private($serviceAccount['private_key']);
        if (!$privateKey) {
            echo "FCM: Failed to load private key. Error: " . openssl_error_string() . "\n";
            return null;
        }
        
        $signature = '';
        if (!openssl_sign($signatureInput, $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
            echo "FCM: Failed to sign JWT. Error: " . openssl_error_string() . "\n";
            return null;
        }
        
        openssl_free_key($privateKey);
        
        $signatureEncoded = $this->base64UrlEncode($signature);
        
        return $signatureInput . '.' . $signatureEncoded;
    }
    
    /**
     * Base64 URL encode (RFC 4648)
     */
    private function base64UrlEncode($data) {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
    
    /**
     * Get FCM token for a user from database
     */
    public function getFCMTokenForUser($userId, $userType = 'staff') {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }
        
        $userId = $mysqli->real_escape_string($userId);
        $userType = $mysqli->real_escape_string($userType);
        
        // Check if FCM tokens are stored in fl_chat_users table
        $sql = "SELECT fcm_token FROM fl_chat_users WHERE ";
        if ($userType == 'staff') {
            $sql .= "staff_id = '$userId' AND user_type = 'staff'";
        } else {
            $sql .= "student_id = '$userId' AND user_type = 'student'";
        }
        $sql .= " LIMIT 1";
        
        $result = $mysqli->query($sql);
        if ($result && $row = $result->fetch_assoc()) {
            $token = $row['fcm_token'];
            $mysqli->close();
            return !empty($token) ? $token : null;
        }
        
        $mysqli->close();
        return null;
    }
    
    /**
     * Get sender name for notification.
     * Admins: staff table, column name. Students: users table, column username.
     */
    public function getSenderName($senderId, $userType = 'staff') {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return 'Someone';
        }
        
        $senderId = $mysqli->real_escape_string($senderId);
        $userType = $mysqli->real_escape_string($userType);
        
        if ($userType == 'staff') {
            $sql = "SELECT name FROM staff WHERE id = '$senderId' LIMIT 1";
        } else {
            // Students: fl_chat_users.student_id = users.user_id
            $sql = "SELECT username FROM users WHERE user_id = '$senderId' LIMIT 1";
        }
        
        $result = $mysqli->query($sql);
        if ($result && $row = $result->fetch_assoc()) {
            if ($userType == 'staff') {
                $name = !empty($row['name']) ? $row['name'] : 'Someone';
            } else {
                $name = !empty($row['username']) ? $row['username'] : 'Someone';
            }
            $mysqli->close();
            return $name;
        }
        
        $mysqli->close();
        return 'Someone';
    }
    
    /**
     * Send FCM notification using v1 API
     */
    public function sendNotification($fcmToken, $title, $body, $data = []) {
        if (empty($this->projectId)) {
            echo "FCM: Project ID not configured. Cannot send notification.\n";
            return false;
        }
        
        if (empty($fcmToken)) {
            echo "FCM: No FCM token provided. Cannot send notification.\n";
            return false;
        }
        
        // Get access token
        $accessToken = $this->getAccessToken();
        if (!$accessToken) {
            echo "FCM: Failed to get access token. Cannot send notification.\n";
            return false;
        }
        
        // Build v1 API message payload
        $message = [
            'message' => [
                'token' => $fcmToken,
                'notification' => [
                    'title' => $title,
                    'body' => $body
                ],
                'data' => array_map('strval', array_merge([
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                    'type' => 'message'
                ], $data)),
                'android' => [
                    'priority' => 'high',
                    'notification' => [
                        'channel_id' => 'messages_channel',
                        'sound' => 'default'
                    ]
                ],
                'apns' => [
                    'payload' => [
                        'aps' => [
                            'sound' => 'default',
                            'badge' => 1,
                            'alert' => [
                                'title' => $title,
                                'body' => $body
                            ]
                        ]
                    ]
                ]
            ]
        ];
        
        // Send via v1 API
        $url = "https://fcm.googleapis.com/v1/projects/{$this->projectId}/messages:send";
        $headers = [
            'Authorization: Bearer ' . $accessToken,
            'Content-Type: application/json'
        ];
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($message));
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);
        
        if ($curlError) {
            echo "FCM: cURL error: $curlError\n";
            return false;
        }
        
        if ($httpCode == 200) {
            echo "FCM: Notification sent successfully to token: " . substr($fcmToken, 0, 20) . "...\n";
            return true;
        } else {
            echo "FCM: Failed to send notification. HTTP Code: $httpCode, Response: $response\n";
            return false;
        }
    }
    
    /**
     * Get FCM tokens for notice board push based on visibility (visible_student, visible_staff, visible_parent).
     * Returns tokens from fl_chat_users: students (user_type=student), staff (user_type=staff, staff_id != 0).
     * Parent/guardian: if your app stores them in fl_chat_users with user_type e.g. 'parent', add a column
     * or use the same as student; here we treat parent as student for token lookup if no parent_id column.
     *
     * @param bool $visibleStudent
     * @param bool $visibleStaff
     * @param bool $visibleParent
     * @return string[] FCM tokens
     */
    public function getFCMTokensForNoticeTarget($visibleStudent, $visibleStaff, $visibleParent) {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return [];
        }
        $conditions = [];
        if ($visibleStudent) {
            $conditions[] = "(user_type = 'student' AND student_id IS NOT NULL AND student_id != 0 AND fcm_token IS NOT NULL AND fcm_token != '')";
        }
        if ($visibleStaff) {
            $conditions[] = "(user_type = 'staff' AND staff_id IS NOT NULL AND staff_id != 0 AND fcm_token IS NOT NULL AND fcm_token != '')";
        }
        if ($visibleParent) {
            // If you have parent_id in fl_chat_users, add: (user_type = 'parent' AND parent_id IS NOT NULL ...)
            // Otherwise parents may use the same app as students; include student tokens as proxy if no separate parent store
            if (!$visibleStudent) {
                $conditions[] = "(user_type = 'student' AND student_id IS NOT NULL AND fcm_token IS NOT NULL AND fcm_token != '')";
            }
        }
        if (empty($conditions)) {
            $mysqli->close();
            return [];
        }
        $sql = "SELECT DISTINCT fcm_token FROM fl_chat_users WHERE (" . implode(' OR ', $conditions) . ")";
        $result = $mysqli->query($sql);
        $tokens = [];
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                if (!empty($row['fcm_token'])) {
                    $tokens[] = $row['fcm_token'];
                }
            }
        }
        $mysqli->close();
        return $tokens;
    }

    /**
     * Get FCM tokens for all staff (excluding Support staff_id=0) for Support inbox notifications
     */
    public function getFCMTokensForAllStaff() {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return [];
        }
        $sql = "SELECT fcm_token FROM fl_chat_users 
                WHERE user_type = 'staff' AND staff_id IS NOT NULL AND staff_id != 0 
                AND fcm_token IS NOT NULL AND fcm_token != ''";
        $result = $mysqli->query($sql);
        $tokens = [];
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                if (!empty($row['fcm_token'])) {
                    $tokens[] = $row['fcm_token'];
                }
            }
        }
        $mysqli->close();
        return $tokens;
    }

    /**
     * Send new-message notification to all staff (when receiver is Support – so admins get push when app is closed)
     */
    public function sendMessageNotificationToAllStaff($senderId, $senderUserType, $message, $chatConnectionId) {
        $tokens = $this->getFCMTokensForAllStaff();
        if (empty($tokens)) {
            echo "FCM: No staff FCM tokens found for Support inbox notification.\n";
            return false;
        }
        $senderName = $this->getSenderName($senderId, $senderUserType);
        $messagePreview = mb_substr($message, 0, 100);
        if (mb_strlen($message) > 100) {
            $messagePreview .= '...';
        }
        $data = [
            'chatId' => $chatConnectionId,
            'senderId' => $senderId,
            'message' => $message
        ];
        $sent = 0;
        foreach ($tokens as $token) {
            if ($this->sendNotification($token, $senderName, $messagePreview, $data)) {
                $sent++;
            }
        }
        echo "FCM: Support inbox notification sent to $sent staff device(s).\n";
        return $sent > 0;
    }

    /**
     * Send notification for new message
     */
    public function sendMessageNotification($receiverUserId, $receiverUserType, $senderId, $senderUserType, $message, $chatConnectionId) {
        // Get FCM token for receiver
        $fcmToken = $this->getFCMTokenForUser($receiverUserId, $receiverUserType);
        
        if (!$fcmToken) {
            echo "FCM: No FCM token found for user $receiverUserId. User may not have granted notification permissions.\n";
            return false;
        }
        
        // Get sender name
        $senderName = $this->getSenderName($senderId, $senderUserType);
        
        // Truncate message if too long
        $messagePreview = mb_substr($message, 0, 100);
        if (mb_strlen($message) > 100) {
            $messagePreview .= '...';
        }
        
        // Send notification
        return $this->sendNotification(
            $fcmToken,
            $senderName,
            $messagePreview,
            [
                'chatId' => $chatConnectionId,
                'senderId' => $senderId,
                'message' => $message
            ]
        );
    }
}
