<?php
/**
 * Student Information — school houses (web: Student House).
 */

header('Content-Type: application/json; charset=utf-8');

function si_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'houses' => []]);
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

    $result = $mysqli->query("SELECT id, house_name FROM school_houses ORDER BY house_name ASC");
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $houses = [];
    while ($row = $result->fetch_assoc()) {
        $houses[] = [
            'id' => (int) $row['id'],
            'house_name' => $row['house_name'] ?? '',
        ];
    }
    $mysqli->close();
    si_send_json(['success' => true, 'houses' => $houses]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    si_send_json(['success' => false, 'error' => $e->getMessage(), 'houses' => []]);
}
