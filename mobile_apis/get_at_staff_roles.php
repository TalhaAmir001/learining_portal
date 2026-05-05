<?php
/**
 * Attendance — staff role names used by staff attendance filter (matches web dropdown).
 * GET: no params. Returns roles where is_active = 'yes'.
 */

header('Content-Type: application/json; charset=utf-8');

function at_json_out($data) {
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
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

    $res = $mysqli->query(
        "SELECT id, name AS role_name FROM roles WHERE is_active = 'yes' ORDER BY id ASC"
    );
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $roles = [];
    while ($row = $res->fetch_assoc()) {
        $roles[] = [
            'id' => (int) $row['id'],
            'role_name' => $row['role_name'] ?? '',
        ];
    }
    $mysqli->close();
    at_json_out(['success' => true, 'roles' => $roles]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    at_json_out(['success' => false, 'error' => $e->getMessage(), 'roles' => []]);
}
