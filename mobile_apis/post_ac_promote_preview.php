<?php
/**
 * Promote Students — preview list (admin).
 *
 * JSON:
 * {
 *   from_class_id: int,
 *   from_section_id: int,
 *   to_session_id: int,
 *   to_class_id: int,
 *   to_section_id: int
 * }
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);
    ac_admin_require_fields($body, array('from_class_id', 'from_section_id', 'to_session_id', 'to_class_id', 'to_section_id'));

    $current_session_id = ac_current_session_id($mysqli);
    if ($current_session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $from_class_id = (int) $body['from_class_id'];
    $from_section_id = (int) $body['from_section_id'];
    $to_session_id = (int) $body['to_session_id'];
    $to_class_id = (int) $body['to_class_id'];
    $to_section_id = (int) $body['to_section_id'];

    if ($from_class_id <= 0 || $from_section_id <= 0 || $to_session_id <= 0 || $to_class_id <= 0 || $to_section_id <= 0) {
        throw new Exception('Invalid inputs.');
    }

    // Mirror Portal query: students in current session class/section, not leave,
    // and who do not already have a session row in target session+class+section.
    $sql = "SELECT
            students.id,
            students.admission_no,
            students.roll_no,
            students.firstname,
            students.middlename,
            students.lastname
        FROM students
        INNER JOIN student_session ss ON ss.student_id = students.id
        LEFT JOIN (
            SELECT id, student_id FROM student_session
            WHERE session_id = " . (int) $to_session_id . "
              AND class_id = " . (int) $to_class_id . "
              AND section_id = " . (int) $to_section_id . "
        ) promoted ON promoted.student_id = students.id
        WHERE ss.is_leave = 0
          AND ss.session_id = " . (int) $current_session_id . "
          AND students.is_active = 'yes'
          AND ss.class_id = " . (int) $from_class_id . "
          AND ss.section_id = " . (int) $from_section_id . "
          AND promoted.id IS NULL
        ORDER BY students.id ASC";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $items = array();
    while ($row = $res->fetch_assoc()) {
        $items[] = array(
            'student_id' => (int) $row['id'],
            'admission_no' => (string) ($row['admission_no'] ?? ''),
            'roll_no' => (string) ($row['roll_no'] ?? ''),
            'firstname' => (string) ($row['firstname'] ?? ''),
            'middlename' => (string) ($row['middlename'] ?? ''),
            'lastname' => (string) ($row['lastname'] ?? ''),
        );
    }

    $mysqli->close();
    ac_admin_success(array(
        'current_session_id' => $current_session_id,
        'items' => $items,
    ));
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_admin_fail($e->getMessage(), array('current_session_id' => 0, 'items' => array()));
}

