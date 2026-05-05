<?php
/**
 * Promote Students — apply (admin).
 *
 * JSON:
 * {
 *   from_class_id: int,
 *   from_section_id: int,
 *   to_session_id: int,
 *   to_class_id: int,
 *   to_section_id: int,
 *   students: [
 *     { student_id: int, result: "pass"|"fail", next_working: "countinue"|"leave" }
 *   ]
 * }
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);
    ac_admin_require_fields($body, array('from_class_id', 'from_section_id', 'to_session_id', 'to_class_id', 'to_section_id', 'students'));

    $current_session_id = ac_current_session_id($mysqli);
    if ($current_session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $from_class_id = (int) $body['from_class_id'];
    $from_section_id = (int) $body['from_section_id'];
    $to_session_id = (int) $body['to_session_id'];
    $to_class_id = (int) $body['to_class_id'];
    $to_section_id = (int) $body['to_section_id'];
    $students = is_array($body['students']) ? $body['students'] : array();

    if ($from_class_id <= 0 || $from_section_id <= 0 || $to_session_id <= 0 || $to_class_id <= 0 || $to_section_id <= 0) {
        throw new Exception('Invalid inputs.');
    }
    if (empty($students)) {
        throw new Exception('No students selected.');
    }

    $mysqli->begin_transaction();

    foreach ($students as $row) {
        if (!is_array($row)) continue;
        $student_id = isset($row['student_id']) ? (int) $row['student_id'] : 0;
        $result = isset($row['result']) ? (string) $row['result'] : 'pass';
        $next = isset($row['next_working']) ? (string) $row['next_working'] : 'countinue';

        if ($student_id <= 0) {
            throw new Exception('Invalid student_id.');
        }

        if ($next === 'leave') {
            // Mark leave in current session row.
            $sql = "UPDATE student_session
                    SET is_leave = 1
                    WHERE session_id = " . (int) $current_session_id . "
                      AND student_id = " . (int) $student_id . "
                      AND class_id = " . (int) $from_class_id . "
                      AND section_id = " . (int) $from_section_id . "
                    LIMIT 1";
            if (!$mysqli->query($sql)) {
                throw new Exception('Leave update failed: ' . $mysqli->error);
            }
            // Alumni status in current session.
            $sql2 = "UPDATE student_session
                     SET is_alumni = 1
                     WHERE session_id = " . (int) $current_session_id . "
                       AND student_id = " . (int) $student_id;
            if (!$mysqli->query($sql2)) {
                throw new Exception('Alumni update failed: ' . $mysqli->error);
            }
            continue;
        }

        // Continue: insert/update target session row.
        $promote_class = ($result === 'pass') ? $to_class_id : $from_class_id;
        $promote_section = ($result === 'pass') ? $to_section_id : $from_section_id;

        // Upsert by (session_id, student_id) like Student_model::add_student_session.
        $q = "SELECT id FROM student_session
              WHERE session_id = " . (int) $to_session_id . "
                AND student_id = " . (int) $student_id . "
              LIMIT 1";
        $qr = $mysqli->query($q);
        if (!$qr) {
            throw new Exception('Lookup failed: ' . $mysqli->error);
        }
        if ($qr->num_rows > 0) {
            $rec = $qr->fetch_assoc();
            $sid = (int) $rec['id'];
            $sql = "UPDATE student_session
                    SET class_id=" . (int) $promote_class . ",
                        section_id=" . (int) $promote_section . ",
                        transport_fees=0,
                        fees_discount=0
                    WHERE id=" . (int) $sid . "
                    LIMIT 1";
            if (!$mysqli->query($sql)) {
                throw new Exception('Update target session failed: ' . $mysqli->error);
            }
        } else {
            $sql = "INSERT INTO student_session (student_id, class_id, section_id, session_id, transport_fees, fees_discount)
                    VALUES (" . (int) $student_id . ", " . (int) $promote_class . ", " . (int) $promote_section . ", " . (int) $to_session_id . ", 0, 0)";
            if (!$mysqli->query($sql)) {
                throw new Exception('Insert target session failed: ' . $mysqli->error);
            }
        }
    }

    $mysqli->commit();
    $mysqli->close();
    ac_admin_success(array('current_session_id' => $current_session_id));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->rollback();
        $mysqli->close();
    }
    ac_admin_fail($e->getMessage());
}

