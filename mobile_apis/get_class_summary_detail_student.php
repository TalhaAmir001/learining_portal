<?php
/**
 * Class summary detail visible for a student (current session).
 *
 * JSON: { student_id: int, summary_id: int }
 *
 * Validates the summary is for student's current class/section. If table exists,
 * marks class_summary_student_read for tracking.
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
    $summary_id = isset($body['summary_id']) ? (int) $body['summary_id'] : 0;
    if ($student_id <= 0) {
        throw new Exception('student_id is required.');
    }
    if ($summary_id <= 0) {
        throw new Exception('summary_id is required.');
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
    $student_session_id = (int) $ss_row['id'];
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
                cs.*,
                c.class AS class_name,
                s.section AS section_name
            FROM class_summaries cs
            LEFT JOIN classes c ON c.id = cs.class_id
            LEFT JOIN sections s ON s.id = cs.section_id
            WHERE cs.id=" . (int) $summary_id . "
              AND cs.class_id=" . (int) $class_id . "
              AND " . $where_section . "
            LIMIT 1";
    $res = $mysqli->query($sql);
    if (!$res) {
        ac_log_error_line($log_file, 'get_class_summary_detail_student query failed; student_id=' . (int)$student_id . '; summary_id=' . (int)$summary_id . '; class_id=' . (int)$class_id . '; section_id=' . (int)$section_id);
        ac_log_error_line($log_file, 'mysql_error=' . $mysqli->error);
        ac_log_error_line($log_file, 'sql=' . $sql);
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    if ($res->num_rows === 0) {
        throw new Exception('Class summary not found (or not accessible).');
    }
    $summary = $res->fetch_assoc();

    $has_student_read_table = false;
    $t = $mysqli->query("SHOW TABLES LIKE 'class_summary_student_read'");
    if ($t && $t->num_rows > 0) {
        $has_student_read_table = true;
    }
    if ($has_student_read_table) {
        $mysqli->query(
            'INSERT INTO class_summary_student_read (class_summary_id, student_id, student_session_id, read_at)
             VALUES (' . (int) $summary_id . ', ' . (int) $student_id . ', ' . (int) $student_session_id . ', NOW())
             ON DUPLICATE KEY UPDATE read_at=NOW(), student_session_id=' . (int) $student_session_id
        );
    }

    $mysqli->close();
    ac_json_out(array(
        'success' => true,
        'session_id' => $session_id,
        'summary' => $summary,
    ));
} catch (Exception $e) {
    ac_log_error_line($log_file, 'get_class_summary_detail_student exception=' . $e->getMessage());
    if ($mysqli) $mysqli->close();
    ac_json_out(array(
        'success' => false,
        'error' => $e->getMessage(),
        'summary' => null,
    ));
}

