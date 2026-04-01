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
     * Get FCM token for a chat user by app UID (staff_id, teacher_id, student_id, or parent_id) and user_type.
     * Use this for chat message notifications so the correct receiver device gets the notification.
     *
     * @param string|int $userId   App user id (staff_id, teacher_id, student_id, or parent_id)
     * @param string     $userType One of: admin, staff, teacher, student, guardian, parent
     * @return string|null FCM token or null
     */
    public function getFCMTokenForChatUserId($userId, $userType = 'staff') {
        if ($userId === null || $userId === '') {
            return null;
        }
        return $this->getFCMTokenForUser($userId, $userType);
    }

    /**
     * Which fl_chat_users column holds the user id for this user_type.
     */
    private function getIdColumnForUserType($userType) {
        $t = strtolower(trim((string) $userType));
        if (in_array($t, ['staff', 'admin'], true)) return 'staff_id';
        if ($t === 'teacher') return 'teacher_id';
        if (in_array($t, ['guardian', 'parent'], true)) return 'parent_id';
        return 'student_id';
    }

    /**
     * Get FCM token for a user by the correct ID column (with fallback for teacher when stored as staff_id).
     * admin/staff → staff_id; teacher → teacher_id (fallback: staff_id + user_type=teacher); student → student_id; guardian/parent → parent_id.
     */
    public function getFCMTokenForUser($userId, $userType = 'staff') {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) return null;
        $userId = $mysqli->real_escape_string((string) $userId);
        $userType = strtolower(trim($mysqli->real_escape_string($userType)));
        $col = $this->getIdColumnForUserType($userType);
        $sql = "SELECT fcm_token FROM fl_chat_users WHERE $col = '$userId' AND fcm_token IS NOT NULL AND fcm_token != '' LIMIT 1";
        $result = $mysqli->query($sql);
        if ($result && ($row = $result->fetch_assoc()) && !empty($row['fcm_token'])) {
            $mysqli->close();
            return $row['fcm_token'];
        }
        // Fallback for teacher: many setups store teacher with staff_id and user_type='teacher' (same id as staff.id)
        if ($userType === 'teacher') {
            $sql = "SELECT fcm_token FROM fl_chat_users WHERE staff_id = '$userId' AND LOWER(TRIM(COALESCE(user_type,''))) = 'teacher' AND fcm_token IS NOT NULL AND fcm_token != '' LIMIT 1";
            $result = $mysqli->query($sql);
            if ($result && ($row = $result->fetch_assoc()) && !empty($row['fcm_token'])) {
                $mysqli->close();
                return $row['fcm_token'];
            }
        }
        $mysqli->close();
        return null;
    }
    
    /**
     * Get sender name for notification.
     * Staff: staff table, column name. Students: users table, column username.
     * Support (staff_id 0): returns "Support". Normalizes user_type to lowercase.
     */
    public function getSenderName($senderId, $userType = 'staff') {
        $userType = strtolower(trim((string) $userType));
        // Support (virtual user) – staff_id 0
        if ($userType === 'staff' && ((string) $senderId === '0' || (int) $senderId === 0)) {
            return 'Support';
        }
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return 'Someone';
        }
        
        $senderId = $mysqli->real_escape_string((string) $senderId);
        $userTypeEsc = $mysqli->real_escape_string($userType);
        
        // Admin/Support/Teacher: staff table. Student: users by user_id. Guardian/Parent: users by id.
        if (in_array($userTypeEsc, ['staff', 'teacher', 'admin'], true)) {
            $sql = "SELECT name FROM staff WHERE id = '$senderId' LIMIT 1";
        } elseif (in_array($userTypeEsc, ['guardian', 'parent'], true)) {
            $sql = "SELECT username FROM users WHERE id = '$senderId' LIMIT 1";
        } else {
            $sql = "SELECT username FROM users WHERE user_id = '$senderId' LIMIT 1";
        }
        
        $result = $mysqli->query($sql);
        if ($result && $row = $result->fetch_assoc()) {
            if (in_array($userTypeEsc, ['staff', 'teacher', 'admin'], true)) {
                $name = !empty($row['name']) ? $row['name'] : 'Someone';
            } elseif (in_array($userTypeEsc, ['guardian', 'parent'], true) && isset($row['username'])) {
                $name = !empty($row['username']) ? $row['username'] : 'Someone';
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
    public function getFCMTokensForNoticeTargetByRole($visibleStudent, $visibleStaff, $visibleParent, $classId = null, $sectionId = null, $sessionId = null) {
        $mysqli = $this->getDbConnection();
        $byRole = ['student' => [], 'staff' => [], 'parent' => []];
        if (!$mysqli) {
            return $byRole;
        }

        $filterByClassSection = ($classId !== null && $sectionId !== null && $sessionId !== null);

        if ($visibleStudent) {
            if ($filterByClassSection) {
                $classId = (int) $classId;
                $sectionId = (int) $sectionId;
                $sessionId = $mysqli->real_escape_string($sessionId);
                $sql = "SELECT DISTINCT f.fcm_token FROM fl_chat_users f
                    INNER JOIN student_session ss ON ss.student_id = f.student_id  AND ss.class_id = " . $classId . " AND ss.section_id = " . $sectionId . " AND ss.session_id = " . $sessionId . "
                    WHERE f.user_type = 'student' AND f.student_id IS NOT NULL AND f.student_id != 0 AND f.fcm_token IS NOT NULL AND f.fcm_token != ''";
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
            $sql = "SELECT DISTINCT fcm_token FROM fl_chat_users WHERE staff_id IS NOT NULL AND staff_id != 0 AND fcm_token IS NOT NULL AND fcm_token != ''";
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
                $sectionId = (int) $sectionId;
                $sessionId = $mysqli->real_escape_string($sessionId);
                $sql = "SELECT DISTINCT s.parent_app_key AS fcm_token FROM students s
                    INNER JOIN student_session ss ON ss.student_id = s.id AND ss.class_id = " . $classId . " AND ss.section_id = " . $sectionId . "
                    WHERE s.parent_app_key IS NOT NULL AND TRIM(s.parent_app_key) != ''";
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
    public function sendNoticeToVisibleRoles($visibleStudent, $visibleStaff, $visibleParent, $title, $body, $notificationId = null, $classId = null, $sectionId = null, $sessionId = null) {
        $byRole = $this->getFCMTokensForNoticeTargetByRole($visibleStudent, $visibleStaff, $visibleParent, $classId, $sectionId, $sessionId);
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
     * Get FCM tokens for all admins (Support inbox notifications).
     * Only rows with staff_id set and not 0 (teachers use teacher_id, so they are not included).
     */
    public function getFCMTokensForAllStaff() {
        return $this->getFCMTokensForAllStaffExcludingSender(null, null, null);
    }

    /**
     * Get FCM tokens for all admins (Support inbox), excluding the sender so they never get their own message.
     * - When sender is admin/staff: exclude row where staff_id = senderId.
     * - When sender is teacher: exclude row where teacher_id = senderId OR (staff_id = senderId AND user_type = 'teacher') so the teacher never gets the FCM even if their row has wrong user_type.
     * Includes user_type IN ('admin','staff') OR user_type IS NULL so legacy admin rows get FCM.
     *
     * @param string|int|null $excludeSenderId sender's API id (staff_id or teacher_id)
     * @param string|null $excludeSenderUserType 'admin','staff','teacher', etc.
     * @param string|int|null $excludeSenderChatUserId fl_chat_users.id of the sender – when set, exclude this row by id so sender never gets FCM
     */
    public function getFCMTokensForAllStaffExcludingSender($excludeSenderId, $excludeSenderUserType = null, $excludeSenderChatUserId = null) {
        $mysqli = $this->getDbConnection();
        if (!$mysqli) {
            return [];
        }
        $sid = ($excludeSenderId !== null && $excludeSenderId !== '') ? $mysqli->real_escape_string((string) $excludeSenderId) : null;
        $senderType = $excludeSenderUserType !== null ? strtolower(trim((string) $excludeSenderUserType)) : null;

        // Recipients: admins only (staff_id != 0). user_type admin/staff or legacy NULL/empty.
        // Do not filter by teacher_id so admins who are also teachers (same row with staff_id + teacher_id) still get Support FCM.
        $sql = "SELECT fcm_token FROM fl_chat_users 
                WHERE staff_id IS NOT NULL AND staff_id != 0 
                AND (LOWER(TRIM(COALESCE(user_type,''))) IN ('admin', 'staff') OR user_type IS NULL OR TRIM(COALESCE(user_type,'')) = '')
                AND fcm_token IS NOT NULL AND fcm_token != ''";

        // Exclude sender row by id when provided (so sender never gets their own message)
        if ($excludeSenderChatUserId !== null && $excludeSenderChatUserId !== '') {
            $eid = $mysqli->real_escape_string((string) $excludeSenderChatUserId);
            $sql .= " AND id != '$eid'";
        }
        if ($sid !== null) {
            if (in_array($senderType, ['admin', 'staff'], true)) {
                $sql .= " AND staff_id != '$sid'";
            }
            // When sender is teacher: do NOT exclude by staff_id (same person may be admin with that staff_id; we exclude teacher row by id/token only)
        }

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

        // Exclude sender's FCM token so they never get their own Support message (by app uid + user_type)
        $senderToken = null;
        if ($excludeSenderId !== null && $excludeSenderId !== '' && $senderType !== null) {
            $senderToken = $this->getFCMTokenForChatUserId($excludeSenderId, $senderType);
        }
        if (!empty($senderToken)) {
            $tokens = array_values(array_filter($tokens, function ($t) use ($senderToken) {
                return $t !== $senderToken;
            }));
        }

        return $tokens;
    }

    /**
     * Send new-message notification to all admins (when receiver is Support).
     * Excludes the sender so they never get their own message (by sender id/type and optionally by sender's fl_chat_users id).
     *
     * @param string|int|null $senderChatUserId fl_chat_users.id of the sender – when set, this row is always excluded so the sender never gets the FCM
     */
    public function sendMessageNotificationToAllStaff($senderId, $senderUserType, $message, $chatConnectionId, $senderChatUserId = null) {
        $tokens = $this->getFCMTokensForAllStaffExcludingSender($senderId, $senderUserType, $senderChatUserId);
        if (empty($tokens)) {
            echo "FCM: No staff FCM tokens found for Support inbox notification (sender=$senderId, type=$senderUserType). Ensure admins have opened the app and have FCM token saved in fl_chat_users with staff_id set and user_type in ('admin','staff').\n";
            return false;
        }
        $senderName = $this->getSenderName($senderId, $senderUserType);
        $messagePreview = mb_substr($message, 0, 100);
        if (mb_strlen($message) > 100) {
            $messagePreview .= '...';
        }
        // Ensure chatId is string for Flutter payload
        $data = [
            'chatId' => (string) $chatConnectionId,
            'senderId' => (string) $senderId,
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
     * Send notification for new message to the chat receiver.
     * FCM token is looked up by receiver's app UID (staff_id, teacher_id, student_id, or parent_id) and user_type.
     *
     * @param string|int $receiverUserId   Receiver's app uid (staff_id, teacher_id, student_id, or parent_id)
     * @param string     $receiverUserType Receiver's user_type: admin, staff, teacher, student, guardian, parent
     * @param string|int $senderId         Sender's app uid
     * @param string     $senderUserType   Sender's user_type
     * @param string     $message           Message text
     * @param string|int $chatConnectionId  Chat connection id
     * @param string|int|null $receiverChatUserId Unused; kept for backward compatibility. Token is always resolved by receiverUserId + receiverUserType.
     */
    public function sendMessageNotification($receiverUserId, $receiverUserType, $senderId, $senderUserType, $message, $chatConnectionId, $receiverChatUserId = null) {
        // Do not send notification to the sender (e.g. teacher should not get push for their own message)
        if ((string) $receiverUserId === (string) $senderId) {
            echo "FCM: Skipping notification - receiver is the sender (user $receiverUserId).\n";
            return true;
        }

        // Look up receiver's FCM token by app uid (staff_id, teacher_id, student_id, parent_id) and user_type
        $fcmToken = $this->getFCMTokenForChatUserId($receiverUserId, $receiverUserType);
        
        if (!$fcmToken) {
            echo "FCM: No FCM token found for receiver (user_id=$receiverUserId, type=$receiverUserType). User may not have granted notification permissions.\n";
            return false;
        }
        
        // Get sender name (staff: staff.name, student: users.username, Support: "Support")
        $senderName = $this->getSenderName($senderId, $senderUserType);
        
        // Truncate message if too long
        $messagePreview = mb_substr($message, 0, 100);
        if (mb_strlen($message) > 100) {
            $messagePreview .= '...';
        }
        
        // Send notification to receiver only
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
