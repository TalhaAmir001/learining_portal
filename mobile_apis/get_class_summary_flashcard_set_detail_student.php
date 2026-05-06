<?php
/**
 * Flashcard set detail (cards_json) visible for a student (current session).
 *
 * JSON: { student_id: int, set_id: int }
 *
 * Validates the set is linked to a class summary matching student's class/section.
 * If progress table exists, records first_opened/last_opened.
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

    $sql = "SELECT
                f.*,
                cs.title AS summary_title,
                cs.class_date,
                c.class AS class_name,
                s.section AS section_name
            FROM class_summary_flashcards f
            INNER JOIN class_summaries cs ON cs.id = f.class_summary_id
            LEFT JOIN classes c ON c.id = f.class_id
            LEFT JOIN sections s ON s.id = f.section_id
            WHERE f.id=" . (int) $set_id . "
              AND cs.class_id=" . (int) $class_id . "
              AND " . $where_section . "
            LIMIT 1";

    $res = $mysqli->query($sql);
    if (!$res) {
        ac_log_error_line($log_file, 'get_class_summary_flashcard_set_detail_student query failed; student_id=' . (int)$student_id . '; set_id=' . (int)$set_id . '; class_id=' . (int)$class_id . '; section_id=' . (int)$section_id);
        ac_log_error_line($log_file, 'mysql_error=' . $mysqli->error);
        ac_log_error_line($log_file, 'sql=' . $sql);
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    if ($res->num_rows === 0) {
        throw new Exception('Flashcard set not found (or not accessible).');
    }
    $set = $res->fetch_assoc();

    // Decode cards_json to cards array (frontend-friendly)
    $cards = array();
    if (isset($set['cards_json']) && trim((string)$set['cards_json']) !== '') {
        $d = json_decode((string) $set['cards_json'], true);
        if (is_array($d)) {
            $cards = $d;
        }
    }

    $progress_exists = false;
    $t = $mysqli->query("SHOW TABLES LIKE 'class_summary_flashcard_progress'");
    if ($t && $t->num_rows > 0) {
        $progress_exists = true;
    }
    if ($progress_exists) {
        $mysqli->query(
            'INSERT INTO class_summary_flashcard_progress (flashcard_set_id, student_id, first_opened_at, last_opened_at, completed_at)
             VALUES (' . (int) $set_id . ', ' . (int) $student_id . ', NOW(), NOW(), NULL)
             ON DUPLICATE KEY UPDATE last_opened_at=NOW()'
        );
    }

    $mysqli->close();
    ac_json_out(array(
        'success' => true,
        'session_id' => $session_id,
        'set' => $set,
        'cards' => $cards,
    ));
} catch (Exception $e) {
    ac_log_error_line($log_file, 'get_class_summary_flashcard_set_detail_student exception=' . $e->getMessage());
    if ($mysqli) $mysqli->close();
    ac_json_out(array(
        'success' => false,
        'error' => $e->getMessage(),
        'set' => null,
    ));
}

