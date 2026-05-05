<?php
/**
 * Announcement posts visible for a student (current session).
 *
 * JSON: { student_id: int }
 *
 * Resolves student's current class/section from student_session for current session,
 * then returns published posts for that class/section.
 */
require_once __DIR__ . '/ac_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);

    $student_id = isset($body['student_id']) ? (int) $body['student_id'] : 0;
    if ($student_id <= 0) {
        throw new Exception('student_id is required.');
    }

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $ss = $mysqli->query(
        'SELECT class_id, section_id FROM student_session
         WHERE student_id=' . $student_id . ' AND session_id=' . (int) $session_id . ' AND is_leave=0
         ORDER BY id DESC LIMIT 1'
    );
    if (!$ss || $ss->num_rows === 0) {
        throw new Exception('Student session not found.');
    }
    $ss_row = $ss->fetch_assoc();
    $class_id = (int) $ss_row['class_id'];
    $section_id = (int) $ss_row['section_id'];
    if ($class_id <= 0 || $section_id <= 0) {
        throw new Exception('Student class/section not found.');
    }

    $sql = "SELECT ap.*, st.name AS staff_firstname, st.surname AS staff_surname
            FROM announcement_posts ap
            LEFT JOIN staff st ON st.id = ap.created_by_staff_id
            WHERE ap.session_id=" . (int) $session_id . "
              AND ap.class_id=" . (int) $class_id . "
              AND ap.section_id=" . (int) $section_id . "
              AND ap.is_published=1
            ORDER BY ap.created_at DESC
            LIMIT 50";
    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $items = array();
    while ($row = $res->fetch_assoc()) {
        $items[] = $row;
    }

    $mysqli->close();
    ac_json_out(array(
        'success' => true,
        'session_id' => $session_id,
        'class_id' => $class_id,
        'section_id' => $section_id,
        'items' => $items,
    ));
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_json_out(array(
        'success' => false,
        'error' => $e->getMessage(),
        'items' => array(),
    ));
}

