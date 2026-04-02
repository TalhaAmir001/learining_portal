<?php
/**
 * Get Support Ticket Detail with replies
 * - Submitter: GET ticket_id, submitted_by_role, submitted_by_id (user must be the submitter).
 * - Staff: GET ticket_id, role=staff (returns any ticket by id).
 */

header('Content-Type: application/json; charset=utf-8');

function sendJson($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response', 'ticket' => null]);
    } else {
        echo $json;
    }
}

$ticket_id = isset($_REQUEST['ticket_id']) ? (int) $_REQUEST['ticket_id'] : 0;
$role_param = isset($_REQUEST['role']) ? trim($_REQUEST['role']) : '';
$submitted_by_role = isset($_REQUEST['submitted_by_role']) ? trim($_REQUEST['submitted_by_role']) : '';
$submitted_by_id = isset($_REQUEST['submitted_by_id']) ? (int) $_REQUEST['submitted_by_id'] : 0;
$staff_mode = ($role_param === 'staff');

if ($ticket_id <= 0) {
    sendJson(['success' => false, 'error' => 'Missing or invalid ticket_id.', 'ticket' => null]);
    exit;
}
if (!$staff_mode && (!in_array($submitted_by_role, ['student', 'parent'], true) || $submitted_by_id <= 0)) {
    sendJson(['success' => false, 'error' => 'Missing or invalid submitted_by_role or submitted_by_id. Use role=staff for staff.', 'ticket' => null]);
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
        $sql = "SELECT id, ticket_id, subject, category, status, priority, submitted_by_role, submitted_by_id,
                       related_student_id, assigned_to, description, attachment, first_reply_at, resolved_at, created_at, updated_at
                FROM support_tickets
                WHERE id = " . $ticket_id;
    } else {
        $role_esc = $mysqli->real_escape_string($submitted_by_role);
        $sql = "SELECT id, ticket_id, subject, category, status, priority, submitted_by_role, submitted_by_id,
                       related_student_id, assigned_to, description, attachment, first_reply_at, resolved_at, created_at, updated_at
                FROM support_tickets
                WHERE id = " . $ticket_id . " AND submitted_by_role = '" . $role_esc . "' AND submitted_by_id = " . $submitted_by_id;
    }
    $result = $mysqli->query($sql);
    if (!$result || $result->num_rows === 0) {
        $mysqli->close();
        sendJson(['success' => false, 'error' => 'Ticket not found or access denied.', 'ticket' => null]);
        exit;
    }

    $ticket = $result->fetch_assoc();
    $ticket['id'] = (int) $ticket['id'];
    $ticket['submitted_by_id'] = (int) $ticket['submitted_by_id'];
    $ticket['related_student_id'] = $ticket['related_student_id'] !== null ? (int) $ticket['related_student_id'] : null;
    $ticket['assigned_to'] = $ticket['assigned_to'] !== null ? (int) $ticket['assigned_to'] : null;

    $replies_sql = "SELECT id, support_ticket_id, reply_by, reply_by_id, message, attachment, created_at, updated_at
                    FROM support_ticket_replies
                    WHERE support_ticket_id = " . $ticket_id . "
                    ORDER BY created_at ASC";
    $replies_result = $mysqli->query($replies_sql);
    $replies = [];
    if ($replies_result) {
        while ($r = $replies_result->fetch_assoc()) {
            $replies[] = [
                'id' => (int) $r['id'],
                'support_ticket_id' => (int) $r['support_ticket_id'],
                'reply_by' => $r['reply_by'],
                'reply_by_id' => (int) $r['reply_by_id'],
                'message' => $r['message'],
                'attachment' => $r['attachment'],
                'created_at' => $r['created_at'],
                'updated_at' => $r['updated_at'],
            ];
        }
    }
    $ticket['replies'] = $replies;

    $mysqli->close();
    sendJson(['success' => true, 'ticket' => $ticket]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sendJson(['success' => false, 'error' => $e->getMessage(), 'ticket' => null]);
}
