<?php
/**
 * Communicate — scheduled Email/SMS (web: Schedule Email / SMS).
 */

header('Content-Type: application/json; charset=utf-8');

function comm_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'messages' => []]);
    } else {
        echo $json;
    }
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

    $limit = isset($_REQUEST['limit']) ? (int) $_REQUEST['limit'] : 150;
    if ($limit <= 0) {
        $limit = 150;
    }
    if ($limit > 300) {
        $limit = 300;
    }

    $sql = "SELECT id, title, template_id, email_template_id, sms_template_id, send_through,
            message, send_mail, send_sms, is_group, is_individual, is_class, is_schedule,
            sent, schedule_date_time, group_list, user_list, send_to, schedule_class,
            schedule_section, created_at, updated_at
        FROM messages
        WHERE is_schedule = 1
        ORDER BY schedule_date_time ASC
        LIMIT " . $limit;

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = [
            'id' => (int) $row['id'],
            'title' => $row['title'] ?? '',
            'send_through' => $row['send_through'] ?? '',
            'message' => $row['message'] ?? '',
            'send_mail' => $row['send_mail'] ?? '',
            'send_sms' => $row['send_sms'] ?? '',
            'sent' => isset($row['sent']) && $row['sent'] !== null ? (int) $row['sent'] : null,
            'schedule_date_time' => $row['schedule_date_time'] ?? '',
            'send_to' => $row['send_to'] ?? '',
            'created_at' => $row['created_at'] ?? '',
        ];
    }
    $mysqli->close();
    comm_send_json(['success' => true, 'messages' => $rows]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    comm_send_json(['success' => false, 'error' => $e->getMessage(), 'messages' => []]);
}
