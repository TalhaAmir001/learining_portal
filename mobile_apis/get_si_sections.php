<?php
/**
 * Student Information — sections for dropdowns.
 * GET: optional class_id. If class_id > 0, returns sections that appear in student_session
 *       for the current school session and that class. Otherwise all sections.
 */

header('Content-Type: application/json; charset=utf-8');

function si_send_json($data) {
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

    $sr = $mysqli->query("SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1");
    if (!$sr || $sr->num_rows === 0) {
        throw new Exception('Could not resolve current session.');
    }
    $sessionRow = $sr->fetch_assoc();
    $session_id = (int) $sessionRow['session_id'];

    $class_id = isset($_REQUEST['class_id']) ? (int) $_REQUEST['class_id'] : 0;
    if ($class_id > 0) {
        $class_id_esc = (int) $class_id;
        $sql = "SELECT DISTINCT s.id, s.section AS section_name
            FROM student_session ss
            INNER JOIN sections s ON s.id = ss.section_id
            WHERE ss.class_id = " . $class_id_esc . "
              AND ss.session_id = " . $session_id . "
            ORDER BY s.section ASC";
        $result = $mysqli->query($sql);
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
    si_send_json(['success' => true, 'sections' => $sections, 'session_id' => $session_id]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    si_send_json(['success' => false, 'error' => $e->getMessage(), 'sections' => []]);
}
