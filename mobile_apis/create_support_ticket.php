<?php
/**
 * Create Support Ticket
 * POST (JSON): subject (required), submitted_by_role (student|parent), submitted_by_id (required),
 *              category (optional slug/name), priority (optional low|medium|high),
 *              related_student_id (optional), description (optional), attachment (optional path/url).
 * Generates ticket_id like TKT-YYYYMMDD-NNNN.
 */

header('Content-Type: application/json; charset=utf-8');
ob_start();

function sendJson($data) {
    if (ob_get_level()) {
        ob_clean();
    }
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response']);
    } else {
        echo $json;
    }
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJson(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
if ($input === null && !empty($_POST)) {
    $input = $_POST;
}
if ($input === null) {
    $input = [];
}

$subject = isset($input['subject']) ? trim($input['subject']) : '';
$submitted_by_role = isset($input['submitted_by_role']) ? trim($input['submitted_by_role']) : '';
$submitted_by_id = isset($input['submitted_by_id']) ? (int) $input['submitted_by_id'] : 0;
$category = isset($input['category']) ? trim($input['category']) : null;
$priority = isset($input['priority']) ? trim($input['priority']) : null;
$related_student_id = isset($input['related_student_id']) ? (int) $input['related_student_id'] : null;
$description = isset($input['description']) ? trim($input['description']) : null;
$attachment = isset($input['attachment']) ? trim($input['attachment']) : null;

if ($subject === '' || !in_array($submitted_by_role, ['student', 'parent'], true) || $submitted_by_id <= 0) {
    sendJson(['success' => false, 'error' => 'Missing or invalid subject, submitted_by_role or submitted_by_id.']);
    exit;
}

if (!in_array($priority, ['low', 'medium', 'high'], true)) {
    $priority = null;
}

$mysqli = null;
try {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        throw new Exception('Database connection failed: ' . $mysqli->connect_error);
    }
    $mysqli->set_charset('utf8mb4');

    $date_prefix = date('Ymd');
    $seq_sql = "SELECT COUNT(*) AS cnt FROM support_tickets WHERE DATE(created_at) = CURDATE()";
    $seq_result = $mysqli->query($seq_sql);
    $seq = 1;
    if ($seq_result && $row = $seq_result->fetch_assoc()) {
        $seq = (int) $row['cnt'] + 1;
    }
    $ticket_id = 'TKT-' . $date_prefix . '-' . str_pad((string) $seq, 4, '0', STR_PAD_LEFT);

    $subject_esc = $mysqli->real_escape_string($subject);
    $role_esc = $mysqli->real_escape_string($submitted_by_role);
    $category_esc = ($category !== null && $category !== '') ? "'" . $mysqli->real_escape_string($category) . "'" : 'NULL';
    $priority_esc = ($priority !== null && $priority !== '') ? "'" . $mysqli->real_escape_string($priority) . "'" : 'NULL';
    $desc_esc = ($description !== null && $description !== '') ? "'" . $mysqli->real_escape_string($description) . "'" : 'NULL';
    $att_esc = ($attachment !== null && $attachment !== '') ? "'" . $mysqli->real_escape_string($attachment) . "'" : 'NULL';
    $related_esc = ($related_student_id !== null && $related_student_id > 0) ? (int) $related_student_id : 'NULL';
    $ticket_id_esc = $mysqli->real_escape_string($ticket_id);

    $sql = "INSERT INTO support_tickets (ticket_id, subject, category, status, priority, submitted_by_role, submitted_by_id, related_student_id, description, attachment, created_at, updated_at)
            VALUES ('" . $ticket_id_esc . "', '" . $subject_esc . "', " . $category_esc . ", 'open', " . $priority_esc . ", '" . $role_esc . "', " . $submitted_by_id . ", " . $related_esc . ", " . $desc_esc . ", " . $att_esc . ", NOW(), NOW())";

    if (!$mysqli->query($sql)) {
        throw new Exception('Insert failed: ' . $mysqli->error);
    }
    $id = (int) $mysqli->insert_id;

    // Push notification to staff/admins: new ticket created
    $tokens_result = $mysqli->query("SELECT fcm_token FROM fl_chat_users WHERE staff_id IS NOT NULL AND staff_id != 0 AND fcm_token IS NOT NULL AND TRIM(fcm_token) != ''");
    if ($tokens_result) {
        $subject_safe = mb_substr($subject, 0, 100);
        if (mb_strlen($subject) > 100) $subject_safe .= '...';
        $data = [
            'type' => 'ticket_created',
            'ticket_id' => (string) $id,
            'subject' => $subject_safe,
            'title' => 'New support ticket',
            'body' => $subject_safe,
        ];
        if (file_exists(__DIR__ . '/../fcm_notification_helper.php')) {
            require_once __DIR__ . '/../fcm_notification_helper.php';
            $fcm = new FCMNotificationHelper();
            while ($row = $tokens_result->fetch_assoc()) {
                if (!empty($row['fcm_token'])) {
                    $fcm->sendDataOnlyMessage($row['fcm_token'], $data);
                }
            }
        }
    }

    $mysqli->close();
    sendJson(['success' => true, 'id' => $id, 'ticket_id' => $ticket_id]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sendJson(['success' => false, 'error' => $e->getMessage()]);
}
