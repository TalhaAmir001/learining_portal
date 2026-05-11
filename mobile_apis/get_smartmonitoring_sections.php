<?php
/**
 * Smart Monitoring – list of sections actually used in the chosen class
 * for the current academic session (Super Admin only).
 *
 * POST JSON:
 *   { api_secret?: string, caller_staff_id: int, class_id: int }
 *
 * Response: { success, sections: [{ id, section_name }], error? }
 *
 * Mirrors the admin branch in get_termfeedback_sections.php and the web's
 * `Class_model::get_section($class_id)` behaviour: only sections that have at
 * least one student enrolled in this class for the current session are
 * returned, so empty sections aren't offered.
 */

require_once __DIR__ . '/sm_bootstrap.php';

$body = sm_read_json_body();
sm_require_api_secret($body);

$class_id = isset($body['class_id']) ? (int) $body['class_id'] : 0;
if ($class_id < 1) {
    sm_json_out(['success' => false, 'error' => 'Missing or invalid class_id', 'sections' => []]);
}

$mysqli = sm_mysqli_connect();
try {
    sm_require_super_admin($mysqli, $body);
    $session_id = sm_current_session_id($mysqli);

    $sql = "SELECT DISTINCT s.id, s.section AS section_name
              FROM student_session ss
              INNER JOIN sections s ON s.id = ss.section_id
             WHERE ss.class_id = $class_id"
         . ($session_id > 0 ? " AND ss.session_id = $session_id" : '')
         . " ORDER BY s.section ASC";

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
    $res->free();
    $mysqli->close();
    sm_json_out(['success' => true, 'sections' => $sections]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sm_json_out(['success' => false, 'error' => $e->getMessage(), 'sections' => []]);
}
