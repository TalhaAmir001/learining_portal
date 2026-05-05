<?php
/**
 * Attendance — subject attendance by date matrix (read-only, mirrors admin subject report by date).
 * GET: class_id, section_id, date (YYYY-MM-DD)
 * Returns timetable slots for that weekday and per-student attendance type id per slot.
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

    $day = date('l', strtotime($date));
    $dayEsc = $mysqli->real_escape_string($day);
    $dEsc = $mysqli->real_escape_string($date);

    $sqlSlots = "SELECT subject_timetable.id AS subject_timetable_id, subjects.name AS subject_name,
            subjects.code, subject_timetable.time_from, subject_timetable.time_to, subject_timetable.start_time
            FROM subject_timetable
            INNER JOIN subject_group_subjects ON subject_group_subjects.id = subject_timetable.subject_group_subject_id
            INNER JOIN subjects ON subjects.id = subject_group_subjects.subject_id
            INNER JOIN staff ON staff.id = subject_timetable.staff_id
            WHERE subject_timetable.class_id = " . $class_id . "
              AND subject_timetable.section_id = " . $section_id . "
              AND subject_timetable.session_id = " . $session_id . "
              AND subject_timetable.day = '" . $dayEsc . "'
              AND staff.is_active = 1
            ORDER BY subject_timetable.start_time ASC";
    $resS = $mysqli->query($sqlSlots);
    if (!$resS) {
        throw new Exception('Slots query failed: ' . $mysqli->error);
    }
    $slots = [];
    $slotIds = [];
    while ($row = $resS->fetch_assoc()) {
        $tid = (int) $row['subject_timetable_id'];
        $slotIds[] = $tid;
        $slots[] = [
            'subject_timetable_id' => $tid,
            'subject_name' => $row['subject_name'] ?? '',
            'code' => $row['code'] ?? '',
            'time_from' => $row['time_from'] ?? '',
            'time_to' => $row['time_to'] ?? '',
            'start_time' => $row['start_time'] ?? '',
        ];
    }

    $sqlStudents = "SELECT student_session.id AS student_session_id, students.id AS student_id,
            students.firstname, students.middlename, students.lastname, students.admission_no, students.roll_no
            FROM students
            INNER JOIN student_session ON students.id = student_session.student_id
            WHERE student_session.session_id = " . $session_id . "
              AND student_session.class_id = " . $class_id . "
              AND student_session.section_id = " . $section_id . "
              AND students.is_active = 'yes'
            ORDER BY students.admission_no ASC";
    $resSt = $mysqli->query($sqlStudents);
    if (!$resSt) {
        throw new Exception('Students query failed: ' . $mysqli->error);
    }

    $attMap = [];
    if (count($slotIds) > 0) {
        $inList = implode(',', array_map('intval', $slotIds));
        $sqlA = "SELECT student_session_id, subject_timetable_id, attendence_type_id, IFNULL(remark,'') AS remark
                FROM student_subject_attendances
                WHERE date = '" . $dEsc . "' AND subject_timetable_id IN (" . $inList . ")";
        $resA = $mysqli->query($sqlA);
        if ($resA) {
            while ($a = $resA->fetch_assoc()) {
                $ssid = (int) $a['student_session_id'];
                $stid = (int) $a['subject_timetable_id'];
                if (!isset($attMap[$ssid])) {
                    $attMap[$ssid] = [];
                }
                $attMap[$ssid][$stid] = [
                    'attendence_type_id' => (int) $a['attendence_type_id'],
                    'remark' => $a['remark'] ?? '',
                ];
            }
        }
    }

    $students = [];
    while ($row = $resSt->fetch_assoc()) {
        $ssid = (int) $row['student_session_id'];
        $bySlot = [];
        foreach ($slotIds as $stid) {
            $bySlot[(string) $stid] = isset($attMap[$ssid][$stid])
                ? $attMap[$ssid][$stid]
                : ['attendence_type_id' => null, 'remark' => ''];
        }
        $students[] = [
            'student_session_id' => $ssid,
            'student_id' => (int) $row['student_id'],
            'admission_no' => $row['admission_no'] ?? '',
            'roll_no' => $row['roll_no'] ?? '',
            'firstname' => $row['firstname'] ?? '',
            'middlename' => $row['middlename'] ?? '',
            'lastname' => $row['lastname'] ?? '',
            'by_slot' => $bySlot,
        ];
    }

    $mysqli->close();
    at_json_out([
        'success' => true,
        'date' => $date,
        'day' => $day,
        'slots' => $slots,
        'students' => $students,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    at_json_out([
        'success' => false,
        'error' => $e->getMessage(),
        'slots' => [],
        'students' => [],
    ]);
}
