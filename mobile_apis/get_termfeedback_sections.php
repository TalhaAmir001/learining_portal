<?php
/**
 * Term Feedback – list of sections for a given class the caller may load feedback for.
 *
 * POST JSON:
 *   { user_type: "admin"|"teacher", staff_id?: int, class_id: int }
 *
 * Response: { success: bool, sections: [{ id, section_name }, ...], error? }
 *
 * Admin sees all sections that have students enrolled in this class for the current session
 * (so empty sections are not offered). Teacher sees only the sections in their lesson scope
 * for that class.
 */

require_once __DIR__ . '/tf_bootstrap.php';

$body = tf_read_json_body();
tf_require_api_secret($body);

$class_id = isset($body['class_id']) ? (int) $body['class_id'] : 0;
if ($class_id < 1) {
    tf_json_out(['success' => false, 'error' => 'Missing or invalid class_id', 'sections' => []]);
}

$mysqli = tf_mysqli_connect();
try {
    $caller = tf_resolve_caller($mysqli, $body);

    if ($caller['role'] === 'teacher') {
        $allowed_section_ids = isset($caller['scope'][$class_id]) ? $caller['scope'][$class_id] : [];
        if (empty($allowed_section_ids)) {
            tf_json_out(['success' => true, 'sections' => []]);
        }
        $ids_csv = implode(',', array_map('intval', $allowed_section_ids));
        $sql = "SELECT id, section AS section_name FROM sections WHERE id IN ($ids_csv) ORDER BY section ASC";
    } else {
        // Admin: only show sections that actually have students in this class for the current session.
        $session_id = (int) $caller['session_id'];
        $sql = "SELECT DISTINCT s.id, s.section AS section_name
                FROM student_session ss
                INNER JOIN sections s ON s.id = ss.section_id
                WHERE ss.class_id = $class_id"
            . ($session_id > 0 ? " AND ss.session_id = $session_id" : '')
            . " ORDER BY s.section ASC";
    }

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $sections = [];
    while ($row = $res->fetch_assoc()) {
        $sections[] = [
            'id'           => (int) $row['id'],
            'section_name' => (string) ($row['section_name'] ?? ''),
        ];
    }
    $mysqli->close();
    tf_json_out(['success' => true, 'sections' => $sections]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    tf_json_out(['success' => false, 'error' => $e->getMessage(), 'sections' => []]);
}
