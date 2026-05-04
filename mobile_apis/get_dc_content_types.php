<?php
/**
 * Download Center / Share Content — content types (web: Content Type).
 */

header('Content-Type: application/json; charset=utf-8');

function dc_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'content_types' => []]);
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
        "SELECT id, name, description, is_active FROM content_types ORDER BY name ASC"
    );
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = [
            'id' => (int) $row['id'],
            'name' => $row['name'] ?? '',
            'description' => $row['description'] ?? '',
            'is_active' => isset($row['is_active']) ? (string) $row['is_active'] : '',
        ];
    }
    $mysqli->close();
    dc_send_json(['success' => true, 'content_types' => $rows]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    dc_send_json(['success' => false, 'error' => $e->getMessage(), 'content_types' => []]);
}
