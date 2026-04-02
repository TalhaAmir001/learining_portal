<?php
/**
 * Get Support Tickets.
 * - For student/parent: GET submitted_by_role (student|parent), submitted_by_id (required) → returns their tickets.
 * - For staff/admin: GET role=staff (optional staff_id) → returns all tickets.
 */

header('Content-Type: application/json; charset=utf-8');

function sendJson($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response', 'tickets' => []]);
    } else {
        echo $json;
    }
}

$role_param = isset($_REQUEST['role']) ? trim($_REQUEST['role']) : '';
$submitted_by_role = isset($_REQUEST['submitted_by_role']) ? trim($_REQUEST['submitted_by_role']) : '';
$submitted_by_id = isset($_REQUEST['submitted_by_id']) ? (int) $_REQUEST['submitted_by_id'] : 0;
$staff_mode = ($role_param === 'staff');

if ($staff_mode) {
    // Staff/admin: return all tickets (no submitted_by filter)
} elseif (in_array($submitted_by_role, ['student', 'parent'], true) && $submitted_by_id > 0) {
    // Student/parent: return their tickets
} else {
    sendJson(['success' => false, 'error' => 'Missing or invalid parameters. Use role=staff for staff, or submitted_by_role + submitted_by_id for student/parent.', 'tickets' => []]);
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
                ORDER BY created_at DESC";
    } else {
        $role_esc = $mysqli->real_escape_string($submitted_by_role);
        $id_esc = (int) $submitted_by_id;
        $sql = "SELECT id, ticket_id, subject, category, status, priority, submitted_by_role, submitted_by_id,
                       related_student_id, assigned_to, description, attachment, first_reply_at, resolved_at, created_at, updated_at
                FROM support_tickets
                WHERE submitted_by_role = '" . $role_esc . "' AND submitted_by_id = " . $id_esc . "
                ORDER BY created_at DESC";
    }
    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $tickets = [];
    while ($row = $result->fetch_assoc()) {
        $tickets[] = [
            'id' => (int) $row['id'],
            'ticket_id' => $row['ticket_id'],
            'subject' => $row['subject'],
            'category' => $row['category'],
            'status' => $row['status'],
            'priority' => $row['priority'],
            'submitted_by_role' => $row['submitted_by_role'],
            'submitted_by_id' => (int) $row['submitted_by_id'],
            'related_student_id' => $row['related_student_id'] !== null ? (int) $row['related_student_id'] : null,
            'assigned_to' => $row['assigned_to'] !== null ? (int) $row['assigned_to'] : null,
            'description' => $row['description'],
            'attachment' => $row['attachment'],
            'first_reply_at' => $row['first_reply_at'],
            'resolved_at' => $row['resolved_at'],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at'],
        ];
    }

    $mysqli->close();
    sendJson(['success' => true, 'tickets' => $tickets]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sendJson(['success' => false, 'error' => $e->getMessage(), 'tickets' => []]);
}
