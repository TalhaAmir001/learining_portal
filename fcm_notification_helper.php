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
     * Get FCM token for a user from fl_chat_users.
     * Tokens are saved per row (save_fcm_token.php updates by fl_chat_users.id); prefer $chatUserRowId when available.
     *
     * @param string|int      $userId          staff_id, student_id (users.user_id), teacher_id, or parent_id (users.id)
     * @param string          $userType        staff|admin|student|guardian|parent|teacher
     * @param string|int|null $chatUserRowId   fl_chat_users.id for the receiver (most reliable)
     */
    public function getFCMTokenForUser($userId, $userType = 'staff', $chatUserRowId = null) {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return null;
        }

        $userTypeNorm = strtolower(trim((string) $userType));
        if ($userTypeNorm === 'parent') {
            $userTypeNorm = 'guardian';
        }

        // Direct row lookup (matches how the app saves the token after login)
        if ($chatUserRowId !== null && $chatUserRowId !== '') {
            $rid = $mysqli->real_escape_string((string) $chatUserRowId);
            $sql = "SELECT fcm_token FROM fl_chat_users WHERE id = '$rid' LIMIT 1";
            $result = $mysqli->query($sql);
            if ($result && $row = $result->fetch_assoc()) {
                $token = $row['fcm_token'];
                if (!empty($token)) {
                    $mysqli->close();
                    return $token;
                }
            }
        }

        $userId = $mysqli->real_escape_string((string) $userId);

        $sql = "SELECT fcm_token FROM fl_chat_users WHERE ";
        if ($userTypeNorm === 'staff' || $userTypeNorm === 'admin') {
            $sql .= "staff_id = '$userId' AND user_type IN ('staff', 'admin')";
        } elseif ($userTypeNorm === 'guardian') {
            $sql .= "parent_id = '$userId' AND user_type IN ('guardian', 'parent')";
        } elseif ($userTypeNorm === 'teacher') {
            $sql .= "teacher_id = '$userId' AND user_type = 'teacher'";
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

        $userTypeNorm = strtolower(trim((string) $userType));
        if ($userTypeNorm === 'parent') {
            $userTypeNorm = 'guardian';
        }

        // Virtual Support user (staff_id = 0 in app / websocket)
        if ((string) $senderId === '0' && ($userTypeNorm === 'staff' || $userTypeNorm === 'admin')) {
            $mysqli->close();
            return 'Support';
        }

        $senderId = $mysqli->real_escape_string((string) $senderId);
        $userType = $mysqli->real_escape_string($userTypeNorm);

        if ($userType == 'staff' || $userType == 'admin') {
            $sql = "SELECT name FROM staff WHERE id = '$senderId' LIMIT 1";
        } elseif ($userType == 'guardian') {
            $sql = "SELECT username FROM users WHERE id = '$senderId' LIMIT 1";
        } elseif ($userType == 'teacher') {
            $sql = "SELECT name FROM staff WHERE id = '$senderId' LIMIT 1";
        } else {
            // Students: fl_chat_users.student_id = users.user_id
            $sql = "SELECT username FROM users WHERE user_id = '$senderId' LIMIT 1";
        }
        
        $result = $mysqli->query($sql);
        if ($result && $row = $result->fetch_assoc()) {
            if ($userType == 'staff' || $userType == 'admin' || $userType == 'teacher') {
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
     * Send FCM data-only message (no automatic notification).
     * Use for notices so the Flutter app's background handler shows a single notification with title "Notice" and notice title as body.
     * When app is closed/background, only the handler runs – no duplicate system notification.
     */
    public function sendDataOnlyMessage($fcmToken, array $data) {
        if (empty($this->projectId)) {
            echo "FCM: Project ID not configured. Cannot send data-only message.\n";
            return false;
        }
        if (empty($fcmToken)) {
            echo "FCM: No FCM token provided. Cannot send data-only message.\n";
            return false;
        }
        $accessToken = $this->getAccessToken();
        if (!$accessToken) {
            echo "FCM: Failed to get access token. Cannot send data-only message.\n";
            return false;
        }
        $data = array_map('strval', $data);
        $message = [
            'message' => [
                'token' => $fcmToken,
                'data' => $data,
                'android' => [
                    'priority' => 'high',
                ],
                'apns' => [
                    'headers' => ['apns-priority' => '10'],
                    'payload' => [
                        'aps' => [
                            'content-available' => 1,
                        ]
                    ]
                ]
            ]
        ];
        return $this->sendFCMRequest($message);
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
        
        return $this->sendFCMRequest($message);
    }

    /**
     * Execute FCM v1 API request
     */
    private function sendFCMRequest(array $message) {
        $url = "https://fcm.googleapis.com/v1/projects/{$this->projectId}/messages:send";
        $headers = [
            'Authorization: Bearer ' . $this->getAccessToken(),
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
            echo "FCM: Notification sent successfully to token: " . substr($message['message']['token'], 0, 20) . "...\n";
            return true;
        } else {
            echo "FCM: Failed to send notification. HTTP Code: $httpCode, Response: $response\n";
            return false;
        }
    }

    /**
     * Get FCM tokens for notice board push grouped by role.
     * Only includes roles that are requested (visible). Student/staff from fl_chat_users; parent from students.parent_app_key.
     * When $classId, $sectionId, $sessionId are all set: students and parents are restricted to that class/section only.
     *
     * @param bool $visibleStudent
     * @param bool $visibleStaff
     * @param bool $visibleParent
     * @param int|null $classId
     * @param int|null $sectionId
     * @param int|null $sessionId
     * @return array ['student' => string[], 'staff' => string[], 'parent' => string[]] (only requested roles have non-empty arrays)
     */
    public function getFCMTokensForNoticeTargetByRole($visibleStudent, $visibleStaff, $visibleParent, $classId = null, $sectionId = null, $sessionId = null, $sectionIdsCsv = null) {
        $mysqli = $this->getDbConnection();
        $byRole = ['student' => [], 'staff' => [], 'parent' => []];
        if (!$mysqli) {
            return $byRole;
        }

        $multiSectionIds = array();
        if ($sectionIdsCsv !== null && trim((string) $sectionIdsCsv) !== '') {
            foreach (explode(',', $sectionIdsCsv) as $p) {
                $i = (int) trim($p);
                if ($i > 0) {
                    $multiSectionIds[] = $i;
                }
            }
            $multiSectionIds = array_values(array_unique($multiSectionIds));
        }
        $filterByClassSection = ($classId !== null && $sessionId !== null && (!empty($multiSectionIds) || ($sectionId !== null && (int) $sectionId > 0)));

        if ($visibleStudent) {
            if ($filterByClassSection) {
                $classId = (int) $classId;
                $sessionId = $mysqli->real_escape_string($sessionId);
                if (!empty($multiSectionIds)) {
                    $inList = implode(',', array_map('intval', $multiSectionIds));
                    $sql = "SELECT DISTINCT f.fcm_token FROM fl_chat_users f
                    INNER JOIN student_session ss ON ss.student_id = f.student_id  AND ss.class_id = " . $classId . " AND ss.section_id IN (" . $inList . ") AND ss.session_id = " . $sessionId . "
                    WHERE f.user_type = 'student' AND f.student_id IS NOT NULL AND f.student_id != 0 AND f.fcm_token IS NOT NULL AND f.fcm_token != ''";
                } else {
                    $sectionId = (int) $sectionId;
                    $sql = "SELECT DISTINCT f.fcm_token FROM fl_chat_users f
                    INNER JOIN student_session ss ON ss.student_id = f.student_id  AND ss.class_id = " . $classId . " AND ss.section_id = " . $sectionId . " AND ss.session_id = " . $sessionId . "
                    WHERE f.user_type = 'student' AND f.student_id IS NOT NULL AND f.student_id != 0 AND f.fcm_token IS NOT NULL AND f.fcm_token != ''";
                }
                    // $sql = "SELECT DISTINCT f.fcm_token FROM fl_chat_users f
                    // INNER JOIN student_session ss ON ss.student_id = f.student_id  AND ss.class_id = '18' AND ss.section_id = '31' AND ss.session_id = '21'
                    // WHERE f.user_type = 'student' AND f.student_id IS NOT NULL AND f.student_id != 0 AND f.fcm_token IS NOT NULL AND f.fcm_token != ''";
            } else {
                $sql = "SELECT DISTINCT fcm_token FROM fl_chat_users WHERE user_type = 'student' AND student_id IS NOT NULL AND student_id != 0 AND fcm_token IS NOT NULL AND fcm_token != ''";
            }
            $result = $mysqli->query($sql);
            if ($result) {
                while ($row = $result->fetch_assoc()) {
                    if (!empty($row['fcm_token'])) {
                        $byRole['student'][] = $row['fcm_token'];
                    }
                }
            }
        }

        if ($visibleStaff) {
            $sql = "SELECT DISTINCT fcm_token FROM fl_chat_users WHERE user_type = 'staff' AND staff_id IS NOT NULL AND staff_id != 0 AND fcm_token IS NOT NULL AND fcm_token != ''";
            $result = $mysqli->query($sql);
            if ($result) {
                while ($row = $result->fetch_assoc()) {
                    if (!empty($row['fcm_token'])) {
                        $byRole['staff'][] = $row['fcm_token'];
                    }
                }
            }
        }

        if ($visibleParent) {
            if ($filterByClassSection) {
                $classId = (int) $classId;
                $sessionId = $mysqli->real_escape_string($sessionId);
                if (!empty($multiSectionIds)) {
                    $inList = implode(',', array_map('intval', $multiSectionIds));
                    $sql = "SELECT DISTINCT s.parent_app_key AS fcm_token FROM students s
                    INNER JOIN student_session ss ON ss.student_id = s.id AND ss.class_id = " . $classId . " AND ss.section_id IN (" . $inList . ") AND ss.session_id = " . $sessionId . "
                    WHERE s.parent_app_key IS NOT NULL AND TRIM(s.parent_app_key) != ''";
                } else {
                    $sectionId = (int) $sectionId;
                    $sql = "SELECT DISTINCT s.parent_app_key AS fcm_token FROM students s
                    INNER JOIN student_session ss ON ss.student_id = s.id AND ss.class_id = " . $classId . " AND ss.section_id = " . $sectionId . "
                    WHERE s.parent_app_key IS NOT NULL AND TRIM(s.parent_app_key) != ''";
                }
            } else {
                $sql = "SELECT DISTINCT parent_app_key AS fcm_token FROM students WHERE parent_app_key IS NOT NULL AND TRIM(parent_app_key) != ''";
            }
            $result = $mysqli->query($sql);
            if ($result) {
                while ($row = $result->fetch_assoc()) {
                    if (!empty($row['fcm_token'])) {
                        $byRole['parent'][] = $row['fcm_token'];
                    }
                }
            }
        }

        $mysqli->close();
        return $byRole;
    }

    /**
     * Get FCM tokens for notice board push based on visibility (visible_student, visible_staff, visible_parent).
     * Returns a flat list of tokens (all visible roles combined). Kept for backward compatibility.
     *
     * @param bool $visibleStudent
     * @param bool $visibleStaff
     * @param bool $visibleParent
     * @return string[] FCM tokens
     */
    public function getFCMTokensForNoticeTarget($visibleStudent, $visibleStaff, $visibleParent) {
        $byRole = $this->getFCMTokensForNoticeTargetByRole($visibleStudent, $visibleStaff, $visibleParent);
        $tokens = array_merge(
            $byRole['student'],
            $byRole['staff'],
            $byRole['parent']
        );
        return array_values(array_unique($tokens));
    }

    /**
     * Send notice FCM in bulk per visible role: only to students if visible_student, only to staff if visible_staff, only to parents if visible_parent.
     * When $classId, $sectionId, $sessionId are all provided, only students (and parents) in that class/section receive the notice.
     *
     * @param bool   $visibleStudent
     * @param bool   $visibleStaff
     * @param bool   $visibleParent
     * @param string $title
     * @param string $body
     * @param int|null $notificationId
     * @param int|null $classId
     * @param int|null $sectionId
     * @param int|null $sessionId
     * @return array ['success' => bool, 'sent' => int, 'by_role' => ['student' => int, 'staff' => int, 'parent' => int]]
     */
    public function sendNoticeToVisibleRoles($visibleStudent, $visibleStaff, $visibleParent, $title, $body, $notificationId = null, $classId = null, $sectionId = null, $sessionId = null, $sectionIdsCsv = null) {
        $byRole = $this->getFCMTokensForNoticeTargetByRole($visibleStudent, $visibleStaff, $visibleParent, $classId, $sectionId, $sessionId, $sectionIdsCsv);
        // Data-only message: app background handler shows one notification with title "Notice" and body = notice title (no duplicate system notification)
        $data = [
            'type' => 'notice',
            'title' => $title,
            'notification_id' => (string) ($notificationId !== null ? $notificationId : ''),
            'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
        ];
        $sentByRole = ['student' => 0, 'staff' => 0, 'parent' => 0];
        $totalSent = 0;

        foreach (['student', 'staff', 'parent'] as $role) {
            $tokens = isset($byRole[$role]) ? $byRole[$role] : [];
            foreach ($tokens as $token) {
                if ($this->sendDataOnlyMessage($token, $data)) {
                    $sentByRole[$role]++;
                    $totalSent++;
                }
            }
        }

        return [
            'success' => true,
            'sent'    => $totalSent,
            'by_role' => $sentByRole,
        ];
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
                WHERE user_type IN ('staff', 'admin') AND staff_id IS NOT NULL AND staff_id != 0 
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
     *
     * Uses notification + data so the OS shows reliably when the app is killed (data-only is unreliable on iOS / some Android).
     * Flutter avoids duplicating in the background handler when message.notification is set.
     *
     * @param string|int|null $messageId fl_chat_messages.id (for tap / dedup in app)
     */
    public function sendMessageNotificationToAllStaff($senderId, $senderUserType, $message, $chatConnectionId, $messageId = null) {
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
        $mid = $messageId !== null && $messageId !== '' ? (string) $messageId : '';
        $data = [
            'chatId' => (string) $chatConnectionId,
            'senderId' => (string) $senderId,
            'message' => $message,
            'body' => $messagePreview,
        ];
        if ($mid !== '') {
            $data['message_id'] = $mid;
        }
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
     * Send FCM for a new chat message (student/guardian/teacher receiver).
     * Sent even when WebSocket already delivered so the app gets onMessage when foreground + reliable tray when killed.
     *
     * @param string|int|null $receiverChatUserRowId fl_chat_users.id for the receiver (preferred for token lookup)
     * @param string|int|null $messageId fl_chat_messages.id
     */
    public function sendMessageNotification($receiverUserId, $receiverUserType, $senderId, $senderUserType, $message, $chatConnectionId, $receiverChatUserRowId = null, $messageId = null) {
        // Get FCM token for receiver
        $fcmToken = $this->getFCMTokenForUser($receiverUserId, $receiverUserType, $receiverChatUserRowId);
        
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

        $mid = $messageId !== null && $messageId !== '' ? (string) $messageId : '';
        $data = [
            'chatId' => (string) $chatConnectionId,
            'senderId' => (string) $senderId,
            'message' => $message,
            'body' => $messagePreview,
        ];
        if ($mid !== '') {
            $data['message_id'] = $mid;
        }

        return $this->sendNotification($fcmToken, $senderName, $messagePreview, $data);
    }
}
