<?php
/**
 * Attendance — student attendence types (Present, Absent, Late, …).
 * GET: no params. Mirrors admin `attendencetype_model->get()`.
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

    $sql = "SELECT id, `type`, key_value, long_lang_name, long_name_style
            FROM attendence_type
            ORDER BY id ASC";
    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $types = [];
    while ($row = $res->fetch_assoc()) {
        $types[] = [
            'id' => (int) $row['id'],
            'type' => $row['type'] ?? '',
            'key_value' => $row['key_value'] ?? '',
            'long_lang_name' => $row['long_lang_name'] ?? '',
            'long_name_style' => $row['long_name_style'] ?? '',
        ];
    }
    $mysqli->close();
    at_json_out(['success' => true, 'types' => $types]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    at_json_out(['success' => false, 'error' => $e->getMessage(), 'types' => []]);
}
