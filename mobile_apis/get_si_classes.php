<?php
/**
 * Student Information — classes list (current academic setup).
 * GET: no params. Returns id and class_name from classes ordered by name.
 */

header('Content-Type: application/json; charset=utf-8');

function si_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'classes' => []]);
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

    $result = $mysqli->query("SELECT id, `class` AS class_name FROM classes ORDER BY `class` ASC");
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $classes = [];
    while ($row = $result->fetch_assoc()) {
        $classes[] = [
            'id' => (int) $row['id'],
            'class_name' => $row['class_name'] ?? '',
        ];
    }
    $mysqli->close();
    si_send_json(['success' => true, 'classes' => $classes]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    si_send_json(['success' => false, 'error' => $e->getMessage(), 'classes' => []]);
}
