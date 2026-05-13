<?php
/**
 * Mark a class-summary flashcard deck as completed for a student (mobile session).
 *
 * JSON: { student_id: int, set_id: int }
 *
 * Same class/section access rules as get_class_summary_flashcard_set_detail_student.php.
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
    $set_id = isset($body['set_id']) ? (int) $body['set_id'] : 0;
    if ($student_id <= 0) {
        throw new Exception('student_id is required.');
    }
    if ($set_id <= 0) {
        throw new Exception('set_id is required.');
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

    $table_check = $mysqli->query("SHOW TABLES LIKE 'class_summary_flashcards'");
    if (!$table_check || $table_check->num_rows === 0) {
        throw new Exception('Flashcards table is missing.');
    }

    $has_section_ids = false;
    $col = $mysqli->query("SHOW COLUMNS FROM class_summaries LIKE 'section_ids'");
    if ($col && $col->num_rows > 0) {
        $has_section_ids = true;
    }
    $sid = (int) $section_id;
    $where_section = 'cs.section_id=' . $sid;
    if ($has_section_ids) {
        $where_section = '(' . $where_section
            . ' OR (cs.section_ids IS NOT NULL AND cs.section_ids <> \'\' AND cs.section_ids REGEXP \'(^|\\\\[|,)\\\\s*' . $sid . '\\\\s*(,|\\\\]|$)\'))';
    }

    $sql = "SELECT f.id
            FROM class_summary_flashcards f
            INNER JOIN class_summaries cs ON cs.id = f.class_summary_id
            WHERE f.id=" . (int) $set_id . "
              AND cs.class_id=" . (int) $class_id . "
              AND " . $where_section . "
            LIMIT 1";

    $res = $mysqli->query($sql);
    if (!$res || $res->num_rows === 0) {
        throw new Exception('Flashcard set not found (or not accessible).');
    }

    $t = $mysqli->query("SHOW TABLES LIKE 'class_summary_flashcard_progress'");
    if (!$t || $t->num_rows === 0) {
        $mysqli->close();
        ac_json_out(array('success' => true, 'message' => 'Progress table not installed.'));
    }

    $mysqli->query(
        'INSERT INTO class_summary_flashcard_progress (flashcard_set_id, student_id, first_opened_at, last_opened_at, completed_at)
         VALUES (' . (int) $set_id . ', ' . (int) $student_id . ', NOW(), NOW(), NOW())
         ON DUPLICATE KEY UPDATE last_opened_at=NOW(), completed_at=NOW()'
    );

    $mysqli->close();
    ac_json_out(array('success' => true));
} catch (Exception $e) {
    ac_log_error_line($log_file, 'complete_class_summary_flashcard_student exception=' . $e->getMessage());
    if ($mysqli) {
        $mysqli->close();
    }
    ac_json_out(array(
        'success' => false,
        'error' => $e->getMessage(),
    ));
}
