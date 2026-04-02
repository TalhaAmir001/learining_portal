<?php
/**
 * Get students from fl_chat_users for a given class and section (for daily feedback).
 * GET: class_id (required), section_id (required).
 * Returns students whose class_section_data JSON contains the given class_id and section_id.
 */

header('Content-Type: application/json; charset=utf-8');

function sendJson($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'students' => []]);
    } else {
        echo $json;
    }
}

$class_id = isset($_REQUEST['class_id']) ? (int) $_REQUEST['class_id'] : 0;
$section_id = isset($_REQUEST['section_id']) ? (int) $_REQUEST['section_id'] : 0;
if ($class_id <= 0 || $section_id <= 0) {
    sendJson(['success' => false, 'error' => 'Missing or invalid class_id and section_id.', 'students' => []]);
    exit;
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

    $result = $mysqli->query("SELECT cu.id AS chat_user_id, cu.student_id, cu.class_section_data,
        (SELECT u.username FROM users u WHERE u.user_id = cu.student_id LIMIT 1) AS username,
        (SELECT TRIM(s.firstname) FROM students s WHERE s.id = cu.student_id LIMIT 1) AS firstname
        FROM fl_chat_users cu
        WHERE cu.user_type = 'student' AND cu.student_id IS NOT NULL AND cu.class_section_data IS NOT NULL AND cu.class_section_data != ''");
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $students = [];
    while ($row = $result->fetch_assoc()) {
        $data = json_decode($row['class_section_data'], true);
        if (!is_array($data)) {
            continue;
        }
        foreach ($data as $entry) {
            $cid = isset($entry['class_id']) ? (int) $entry['class_id'] : 0;
            $sid = isset($entry['section_id']) ? (int) $entry['section_id'] : 0;
            if ($cid === $class_id && $sid === $section_id) {
                $firstname = isset($row['firstname']) ? trim((string) $row['firstname']) : null;
                $username = isset($row['username']) ? trim((string) $row['username']) : null;
                $students[] = [
                    'chat_user_id' => (int) $row['chat_user_id'],
                    'student_id' => (int) $row['student_id'],
                    'firstname' => $firstname !== '' ? $firstname : null,
                    'username' => $username !== '' ? $username : null,
                    'class_name' => $entry['class_name'] ?? '',
                    'section_name' => $entry['section_name'] ?? '',
                ];
                break;
            }
        }
    }
    $mysqli->close();
    sendJson(['success' => true, 'students' => $students]);
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    sendJson(['success' => false, 'error' => $e->getMessage(), 'students' => []]);
}
