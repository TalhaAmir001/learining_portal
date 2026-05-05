<?php
/**
 * Batch upsert subject_timetable (Portal Timetable::savegroup parity).
 * JSON: delete_ids (int[]), update (object[]), insert (object[]).
 * Each row: class_id, section_id, day, subject_group_id, subject_group_subject_id, staff_id,
 *           time_from, time_to, room_no; update rows also need id.
 */

require_once __DIR__ . '/ac_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $delete_ids = isset($body['delete_ids']) && is_array($body['delete_ids']) ? $body['delete_ids'] : array();
    $insert = isset($body['insert']) && is_array($body['insert']) ? $body['insert'] : array();
    $update = isset($body['update']) && is_array($body['update']) ? $body['update'] : array();

    $mysqli->begin_transaction();

    foreach ($delete_ids as $did) {
        $id = (int) $did;
        if ($id <= 0) {
            continue;
        }
        $res = $mysqli->query(
            'DELETE FROM subject_timetable WHERE id = ' . $id . ' AND session_id = ' . (int) $session_id . ' LIMIT 1'
        );
        if (!$res) {
            throw new Exception('Delete failed: ' . $mysqli->error);
        }
    }

    $process_row = function ($row, $is_update, $existing_id) use ($mysqli, $session_id) {
        $class_id = (int) (isset($row['class_id']) ? $row['class_id'] : 0);
        $section_id = (int) (isset($row['section_id']) ? $row['section_id'] : 0);
        $day = isset($row['day']) ? trim((string) $row['day']) : '';
        $subject_group_id = (int) (isset($row['subject_group_id']) ? $row['subject_group_id'] : 0);
        $subject_group_subject_id = (int) (isset($row['subject_group_subject_id']) ? $row['subject_group_subject_id'] : 0);
        $staff_id = (int) (isset($row['staff_id']) ? $row['staff_id'] : 0);
        $time_from = isset($row['time_from']) ? trim((string) $row['time_from']) : '';
        $time_to = isset($row['time_to']) ? trim((string) $row['time_to']) : '';
        $room_no = isset($row['room_no']) ? trim((string) $row['room_no']) : '';

        if ($class_id <= 0 || $section_id <= 0 || $day === '' || $subject_group_id <= 0
            || $subject_group_subject_id <= 0 || $staff_id <= 0 || $time_from === '' || $time_to === '') {
            throw new Exception('Missing required fields on timetable row.');
        }

        $st = $mysqli->prepare(
            'SELECT subject_group_id FROM subject_group_subjects
            WHERE id = ? AND session_id = ? LIMIT 1'
        );
        if (!$st) {
            throw new Exception('Prepare failed: ' . $mysqli->error);
        }
        $st->bind_param('ii', $subject_group_subject_id, $session_id);
        $st->execute();
        $gr = $st->get_result();
        if (!$gr || $gr->num_rows === 0) {
            throw new Exception('Invalid subject_group_subject_id for this session.');
        }
        $sg_row = $gr->fetch_assoc();
        $db_group = (int) $sg_row['subject_group_id'];
        if ($db_group !== $subject_group_id) {
            throw new Exception('subject_group_id does not match subject_group_subject_id.');
        }

        $st2 = $mysqli->prepare('SELECT id FROM staff WHERE id = ? AND is_active = 1 LIMIT 1');
        if (!$st2) {
            throw new Exception('Prepare failed: ' . $mysqli->error);
        }
        $st2->bind_param('i', $staff_id);
        $st2->execute();
        if ($st2->get_result()->num_rows === 0) {
            throw new Exception('Invalid or inactive staff_id.');
        }

        $start_time = ac_portal_start_time($time_from);
        $end_time = ac_portal_start_time($time_to);
        if ($start_time === '' || $end_time === '') {
            throw new Exception('Could not parse time_from / time_to.');
        }
        $sm = ac_time_to_minutes($start_time);
        $em = ac_time_to_minutes($end_time);
        if ($sm === null || $em === null || $em <= $sm) {
            throw new Exception('Invalid time range (end must be after start).');
        }

        $day_esc = $mysqli->real_escape_string($day);
        $exclude = $is_update ? (int) $existing_id : 0;
        if (ac_has_overlap($mysqli, $session_id, $class_id, $section_id, $day_esc, $sm, $em, $exclude)) {
            throw new Exception('Timetable overlap on that day for this class and section.');
        }

        $room_esc = $mysqli->real_escape_string($room_no);
        $time_from_esc = $mysqli->real_escape_string($time_from);
        $time_to_esc = $mysqli->real_escape_string($time_to);
        $start_esc = $mysqli->real_escape_string($start_time);
        $end_esc = $mysqli->real_escape_string($end_time);

        if ($is_update) {
            $id = (int) $existing_id;
            if ($id <= 0) {
                throw new Exception('Update row requires id.');
            }
            $sql = "UPDATE subject_timetable SET
                day = '" . $day_esc . "',
                class_id = " . (int) $class_id . ",
                section_id = " . (int) $section_id . ",
                subject_group_id = " . (int) $subject_group_id . ",
                subject_group_subject_id = " . (int) $subject_group_subject_id . ",
                staff_id = " . (int) $staff_id . ",
                time_from = '" . $time_from_esc . "',
                time_to = '" . $time_to_esc . "',
                start_time = '" . $start_esc . "',
                end_time = '" . $end_esc . "',
                room_no = '" . $room_esc . "'
                WHERE id = " . (int) $id . " AND session_id = " . (int) $session_id . " LIMIT 1";
            if (!$mysqli->query($sql)) {
                throw new Exception('Update failed: ' . $mysqli->error);
            }
            if ($mysqli->affected_rows < 1) {
                throw new Exception('Update failed: row not found or session mismatch.');
            }
        } else {
            $sql = "INSERT INTO subject_timetable (
                day, class_id, section_id, subject_group_id, subject_group_subject_id,
                staff_id, time_from, time_to, start_time, end_time, room_no, session_id
            ) VALUES (
                '" . $day_esc . "',
                " . (int) $class_id . ",
                " . (int) $section_id . ",
                " . (int) $subject_group_id . ",
                " . (int) $subject_group_subject_id . ",
                " . (int) $staff_id . ",
                '" . $time_from_esc . "',
                '" . $time_to_esc . "',
                '" . $start_esc . "',
                '" . $end_esc . "',
                '" . $room_esc . "',
                " . (int) $session_id . "
            )";
            if (!$mysqli->query($sql)) {
                throw new Exception('Insert failed: ' . $mysqli->error);
            }
        }
    };

    foreach ($update as $row) {
        if (!is_array($row)) {
            continue;
        }
        $eid = (int) (isset($row['id']) ? $row['id'] : 0);
        if ($eid <= 0) {
            throw new Exception('Each update row requires id.');
        }
        $process_row($row, true, $eid);
    }

    foreach ($insert as $row) {
        if (!is_array($row)) {
            continue;
        }
        $process_row($row, false, 0);
    }

    $mysqli->commit();
    $mysqli->close();
    ac_json_out(array('success' => true, 'message' => 'Saved.'));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->rollback();
        $mysqli->close();
    }
    ac_json_out(array('success' => false, 'error' => $e->getMessage()));
}
