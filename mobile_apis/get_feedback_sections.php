<?php
/**
 * Get sections list for daily feedback (admin).
 * GET: optional class_id. If class_id is provided, returns only sections that have students in that class (via student_session). Otherwise returns all sections.
 */

header('Content-Type: application/json; charset=utf-8');

function sendJson($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'sections' => []]);
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

    $class_id = isset($_REQUEST['class_id']) ? (int) $_REQUEST['class_id'] : 0;
    if ($class_id > 0) {
        $class_esc = $mysqli->real_escape_string($class_id);
        $result = $mysqli->query("SELECT DISTINCT s.id, s.section AS section_name
            FROM student_session ss
            INNER JOIN sections s ON s.id = ss.section_id
            WHERE ss.class_id = " . $class_esc . "
            ORDER BY s.section ASC");
    } else {
        $result = $mysqli->query("SELECT id, section AS section_name FROM sections ORDER BY section ASC");
    }
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $sections = [];
    while ($row = $result->fetch_assoc()) {
        $sections[] = [
            'id' => (int) $row['id'],
            'section_name' => $row['section_name'] ?? '',
        ];
    }
    $mysqli->close();
    sendJson(['success' => true, 'sections' => $sections]);
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    sendJson(['success' => false, 'error' => $e->getMessage(), 'sections' => []]);
}
