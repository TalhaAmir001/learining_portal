<?php
/**
 * Communicate — single message row (full body for detail screen).
 * GET: id (required).
 */

header('Content-Type: application/json; charset=utf-8');

function comm_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'message' => null]);
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

    $id = isset($_REQUEST['id']) ? (int) $_REQUEST['id'] : 0;
    if ($id <= 0) {
        throw new Exception('Missing or invalid id.');
    }

    $sql = "SELECT id, title, template_id, email_template_id, sms_template_id, send_through,
            message, send_mail, send_sms, is_group, is_individual, is_class, is_schedule,
            sent, schedule_date_time, group_list, user_list, send_to, schedule_class,
            schedule_section, created_at, updated_at
        FROM messages WHERE id = " . $id . " LIMIT 1";

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    if ($result->num_rows === 0) {
        $mysqli->close();
        comm_send_json(['success' => false, 'error' => 'Not found.', 'message' => null]);
        exit;
    }
    $row = $result->fetch_assoc();
    $out = [
        'id' => (int) $row['id'],
        'title' => $row['title'] ?? '',
        'template_id' => $row['template_id'] ?? '',
        'send_through' => $row['send_through'] ?? '',
        'message' => $row['message'] ?? '',
        'send_mail' => $row['send_mail'] ?? '',
        'send_sms' => $row['send_sms'] ?? '',
        'is_group' => $row['is_group'] ?? '',
        'is_individual' => $row['is_individual'] ?? '',
        'is_class' => isset($row['is_class']) ? (int) $row['is_class'] : 0,
        'is_schedule' => isset($row['is_schedule']) ? (int) $row['is_schedule'] : 0,
        'sent' => isset($row['sent']) && $row['sent'] !== null ? (int) $row['sent'] : null,
        'schedule_date_time' => $row['schedule_date_time'] ?? '',
        'group_list' => $row['group_list'] ?? '',
        'user_list' => $row['user_list'] ?? '',
        'send_to' => $row['send_to'] ?? '',
        'schedule_class' => isset($row['schedule_class']) ? (int) $row['schedule_class'] : null,
        'schedule_section' => $row['schedule_section'] ?? '',
        'created_at' => $row['created_at'] ?? '',
        'updated_at' => $row['updated_at'] ?? '',
    ];
    $mysqli->close();
    comm_send_json(['success' => true, 'message' => $out]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    comm_send_json(['success' => false, 'error' => $e->getMessage(), 'message' => null]);
}
