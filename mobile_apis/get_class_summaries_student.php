<?php
/**
 * Class summaries visible for a student (current session).
 *
 * JSON: { student_id: int }
 *
 * Resolves student's current class/section from student_session for current session,
 * then returns class_summaries for that class/section (supports optional section_ids JSON column).
 */
require_once __DIR__ . '/ac_bootstrap.php';

$log_file = __DIR__ . '/ac_api_errors.log';
function ac_log_error_line($log_file, $msg) {
    @file_put_contents($log_file, '[' . date('Y-m-d H:i:s') . '] ' . $msg . "\n", FILE_APPEND);
}

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
        'SELECT id, class_id, section_id FROM student_session
         WHERE student_id=' . (int) $student_id . ' AND session_id=' . (int) $session_id . ' AND is_leave=0
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

    $has_section_ids = false;
    $col = $mysqli->query("SHOW COLUMNS FROM class_summaries LIKE 'section_ids'");
    if ($col && $col->num_rows > 0) {
        $has_section_ids = true;
    }

    $where_section = 'cs.section_id=' . (int) $section_id;
    if ($has_section_ids) {
        // section_ids is stored as TEXT containing a JSON array like "[1,2,3]".
        // Avoid JSON_* functions for compatibility with older MySQL versions.
        $sid = (int) $section_id;
        $where_section = '(' . $where_section
            . ' OR (cs.section_ids IS NOT NULL AND cs.section_ids <> \'\' AND cs.section_ids REGEXP \'(^|\\\\[|,)\\\\s*' . $sid . '\\\\s*(,|\\\\]|$)\'))';
    }

    $sql = "SELECT
                cs.id,
                cs.class_id,
                cs.section_id,
                cs.class_date,
                cs.title,
                cs.created_by,
                cs.created_at,
                cs.updated_at,
                c.class AS class_name,
                s.section AS section_name
            FROM class_summaries cs
            LEFT JOIN classes c ON c.id = cs.class_id
            LEFT JOIN sections s ON s.id = cs.section_id
            WHERE cs.class_id=" . (int) $class_id . "
              AND " . $where_section . "
            ORDER BY cs.class_date DESC, cs.created_at DESC
            LIMIT 100";

    $res = $mysqli->query($sql);
    if (!$res) {
        ac_log_error_line($log_file, 'get_class_summaries_student query failed; student_id=' . (int)$student_id . '; class_id=' . (int)$class_id . '; section_id=' . (int)$section_id);
        ac_log_error_line($log_file, 'mysql_error=' . $mysqli->error);
        ac_log_error_line($log_file, 'sql=' . $sql);
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
    ac_log_error_line($log_file, 'get_class_summaries_student exception=' . $e->getMessage());
    if ($mysqli) $mysqli->close();
    ac_json_out(array(
        'success' => false,
        'error' => $e->getMessage(),
        'items' => array(),
    ));
}

