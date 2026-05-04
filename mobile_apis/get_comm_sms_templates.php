<?php
/**
 * Communicate — SMS templates.
 */

header('Content-Type: application/json; charset=utf-8');

function comm_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'templates' => []]);
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

    $result = $mysqli->query(
        "SELECT id, title, message, created_at, updated_at FROM sms_template ORDER BY id DESC"
    );
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = [
            'id' => (int) $row['id'],
            'title' => $row['title'] ?? '',
            'message' => $row['message'] ?? '',
            'created_at' => $row['created_at'] ?? '',
            'updated_at' => $row['updated_at'] ?? '',
        ];
    }
    $mysqli->close();
    comm_send_json(['success' => true, 'templates' => $rows]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    comm_send_json(['success' => false, 'error' => $e->getMessage(), 'templates' => []]);
}
