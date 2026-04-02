<?php
/**
 * Add Reply to Support Ticket
 * POST (JSON): support_ticket_id (required), reply_by (student|parent), reply_by_id (required), message (required), attachment (optional).
 * Verifies ticket belongs to submitter and updates first_reply_at if this is the first reply.
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

$support_ticket_id = isset($input['support_ticket_id']) ? (int) $input['support_ticket_id'] : 0;
$reply_by = isset($input['reply_by']) ? trim($input['reply_by']) : '';
$reply_by_id = isset($input['reply_by_id']) ? trim($input['reply_by_id']) : '';
$message = isset($input['message']) ? trim($input['message']) : '';
$attachment = isset($input['attachment']) ? trim($input['attachment']) : null;

$staff_mode = ($reply_by === 'staff');
$valid_role = $staff_mode || in_array($reply_by, ['student', 'parent'], true);

if ($support_ticket_id <= 0 || !$valid_role || $reply_by_id === '' || $message === '') {
    sendJson(['success' => false, 'error' => 'Missing or invalid support_ticket_id, reply_by (student|parent|staff), reply_by_id or message.']);
    exit;
}

$reply_by_id_int = (int) $reply_by_id;
if ($reply_by_id_int <= 0) {
    sendJson(['success' => false, 'error' => 'Invalid reply_by_id.']);
    exit;
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

    if ($staff_mode) {
        $chk = $mysqli->query("SELECT id, first_reply_at FROM support_tickets WHERE id = " . $support_ticket_id);
    } else {
        $chk = $mysqli->query("SELECT id, first_reply_at FROM support_tickets WHERE id = " . $support_ticket_id . " AND submitted_by_role = '" . $mysqli->real_escape_string($reply_by) . "' AND submitted_by_id = " . $reply_by_id_int);
    }
    if (!$chk || $chk->num_rows === 0) {
        $mysqli->close();
        sendJson(['success' => false, 'error' => $staff_mode ? 'Ticket not found.' : 'Ticket not found or you are not the submitter.']);
        exit;
    }
    $ticket_row = $chk->fetch_assoc();
    $first_reply_at = $ticket_row['first_reply_at'];

    $message_esc = $mysqli->real_escape_string($message);
    $att_esc = ($attachment !== null && $attachment !== '') ? "'" . $mysqli->real_escape_string($attachment) . "'" : 'NULL';
    $reply_by_esc = $mysqli->real_escape_string($reply_by);

    $ins = "INSERT INTO support_ticket_replies (support_ticket_id, reply_by, reply_by_id, message, attachment, created_at, updated_at)
            VALUES (" . $support_ticket_id . ", '" . $reply_by_esc . "', " . $reply_by_id_int . ", '" . $message_esc . "', " . $att_esc . ", NOW(), NOW())";
    if (!$mysqli->query($ins)) {
        throw new Exception('Insert reply failed: ' . $mysqli->error);
    }

    if ($first_reply_at === null || $first_reply_at === '') {
        $mysqli->query("UPDATE support_tickets SET first_reply_at = NOW(), updated_at = NOW() WHERE id = " . $support_ticket_id);
    }

    // Push notification: staff replied -> notify submitter; student/parent replied -> notify staff
    $message_preview = mb_substr($message, 0, 80);
    if (mb_strlen($message) > 80) $message_preview .= '...';
    $data = [
        'type' => 'ticket_reply',
        'ticket_id' => (string) $support_ticket_id,
        'message' => $message_preview,
        'title' => 'New reply on ticket',
        'body' => $message_preview,
    ];
    if (file_exists(__DIR__ . '/../fcm_notification_helper.php')) {
        require_once __DIR__ . '/../fcm_notification_helper.php';
        $fcm = new FCMNotificationHelper();
        if ($staff_mode) {
            $ticket_row = $mysqli->query("SELECT submitted_by_id, submitted_by_role FROM support_tickets WHERE id = " . $support_ticket_id);
            if ($ticket_row && $tr = $ticket_row->fetch_assoc()) {
                $sub_id = (int) $tr['submitted_by_id'];
                $sub_role = $mysqli->real_escape_string($tr['submitted_by_role']);
                $col = ($sub_role === 'parent') ? 'parent_id' : 'student_id';
                $tok = $mysqli->query("SELECT fcm_token FROM fl_chat_users WHERE $col = " . $sub_id . " AND fcm_token IS NOT NULL AND TRIM(fcm_token) != '' LIMIT 1");
                if ($tok && $trow = $tok->fetch_assoc() && !empty($trow['fcm_token'])) {
                    $fcm->sendDataOnlyMessage($trow['fcm_token'], $data);
                }
            }
        } else {
            $tokens_result = $mysqli->query("SELECT fcm_token FROM fl_chat_users WHERE staff_id IS NOT NULL AND staff_id != 0 AND fcm_token IS NOT NULL AND TRIM(fcm_token) != ''");
            if ($tokens_result) {
                while ($row = $tokens_result->fetch_assoc()) {
                    if (!empty($row['fcm_token'])) {
                        $fcm->sendDataOnlyMessage($row['fcm_token'], $data);
                    }
                }
            }
        }
    }

    $mysqli->close();
    sendJson(['success' => true]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sendJson(['success' => false, 'error' => $e->getMessage()]);
}
