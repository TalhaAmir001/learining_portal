<?php
/**
 * Attendance — subject timetable slots for a class/section on calendar date (day-of-week from date).
 * GET: class_id, section_id, date (YYYY-MM-DD)
 * Mirrors Subjecttimetable_model subject list for that day (no per-teacher filter).
 */

header('Content-Type: application/json; charset=utf-8');

function at_json_out($data) {
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
}

function at_valid_date($d) {
    if (!is_string($d) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $d)) {
        return false;
    }
    $p = explode('-', $d);
    return checkdate((int) $p[1], (int) $p[2], (int) $p[0]);
}

$mysqli = null;
try {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        throw new Exception('Database connection failed: ' . $mysqli->connect_error);
    }
    $mysqli->set_charset('utf8mb4');

    $class_id = isset($_GET['class_id']) ? (int) $_GET['class_id'] : 0;
    $section_id = isset($_GET['section_id']) ? (int) $_GET['section_id'] : 0;
    $date = isset($_GET['date']) ? trim((string) $_GET['date']) : '';
    if ($class_id <= 0 || $section_id <= 0 || !at_valid_date($date)) {
        throw new Exception('class_id, section_id, and valid date (YYYY-MM-DD) are required.');
    }

    $sr = $mysqli->query("SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1");
    if (!$sr || $sr->num_rows === 0) {
        throw new Exception('Could not resolve current session.');
    }
    $session_id = (int) $sr->fetch_assoc()['session_id'];

    $ts = strtotime($date);
    $day = date('l', $ts);
    $dayEsc = $mysqli->real_escape_string($day);

    $sql = "SELECT subject_group_subjects.subject_id, subjects.name AS subject_name, subjects.code, subjects.type,
            staff.name AS staff_firstname, staff.surname AS staff_surname, staff.employee_id,
            subject_timetable.id AS subject_timetable_id, subject_timetable.time_from, subject_timetable.time_to,
            subject_timetable.start_time, subject_timetable.day, subject_timetable.room_no
            FROM subject_timetable
            INNER JOIN subject_group_subjects ON subject_timetable.subject_group_subject_id = subject_group_subjects.id
            INNER JOIN subjects ON subject_group_subjects.subject_id = subjects.id
            INNER JOIN staff ON staff.id = subject_timetable.staff_id
            WHERE subject_timetable.class_id = " . $class_id . "
              AND subject_timetable.section_id = " . $section_id . "
              AND subject_timetable.session_id = " . $session_id . "
              AND subject_timetable.day = '" . $dayEsc . "'
              AND staff.is_active = 1
            ORDER BY subject_timetable.start_time ASC";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $slots = [];
    while ($row = $res->fetch_assoc()) {
        $slots[] = [
            'subject_timetable_id' => (int) $row['subject_timetable_id'],
            'subject_id' => (int) $row['subject_id'],
            'subject_name' => $row['subject_name'] ?? '',
            'code' => $row['code'] ?? '',
            'type' => $row['type'] ?? '',
            'time_from' => $row['time_from'] ?? '',
            'time_to' => $row['time_to'] ?? '',
            'start_time' => $row['start_time'] ?? '',
            'day' => $row['day'] ?? '',
            'room_no' => $row['room_no'] ?? '',
            'staff_firstname' => $row['staff_firstname'] ?? '',
            'staff_surname' => $row['staff_surname'] ?? '',
            'employee_id' => $row['employee_id'] ?? '',
        ];
    }

    $mysqli->close();
    at_json_out(['success' => true, 'day' => $day, 'slots' => $slots]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    at_json_out(['success' => false, 'error' => $e->getMessage(), 'day' => '', 'slots' => []]);
}
