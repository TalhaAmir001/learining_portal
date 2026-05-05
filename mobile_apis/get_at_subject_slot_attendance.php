<?php
/**
 * Attendance — students + subject period attendance for one timetable slot.
 * GET: class_id, section_id, subject_timetable_id, date (YYYY-MM-DD)
 * Mirrors Studentsubjectattendence_model::searchAttendenceClassSection.
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
    $stid = isset($_GET['subject_timetable_id']) ? (int) $_GET['subject_timetable_id'] : 0;
    $date = isset($_GET['date']) ? trim((string) $_GET['date']) : '';
    if ($class_id <= 0 || $section_id <= 0 || $stid <= 0 || !at_valid_date($date)) {
        throw new Exception('class_id, section_id, subject_timetable_id, and valid date are required.');
    }

    $sr = $mysqli->query("SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1");
    if (!$sr || $sr->num_rows === 0) {
        throw new Exception('Could not resolve current session.');
    }
    $session_id = (int) $sr->fetch_assoc()['session_id'];

    $dEsc = $mysqli->real_escape_string($date);

    $sql = "SELECT IFNULL(student_subject_attendances.id, '0') AS student_subject_attendance_id,
            student_subject_attendances.subject_timetable_id,
            student_subject_attendances.attendence_type_id,
            IFNULL(student_subject_attendances.date, 'xxx') AS date,
            student_subject_attendances.remark,
            students.firstname, students.middlename, students.lastname, students.admission_no, students.roll_no, students.id AS student_id,
            student_session.id AS student_session_id
            FROM students
            INNER JOIN student_session ON students.id = student_session.student_id
              AND student_session.class_id = " . $class_id . "
              AND student_session.section_id = " . $section_id . "
              AND student_session.session_id = " . $session_id . "
            LEFT JOIN student_subject_attendances ON student_session.id = student_subject_attendances.student_session_id
              AND student_subject_attendances.subject_timetable_id = " . $stid . "
              AND student_subject_attendances.date = '" . $dEsc . "'
            WHERE students.is_active = 'yes'
            ORDER BY students.admission_no ASC";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $students = [];
    $is_first = true;
    while ($row = $res->fetch_assoc()) {
        $tid = $row['attendence_type_id'];
        if ($tid !== null && $tid !== '' && (int) $tid > 0) {
            $is_first = false;
        }
        $students[] = [
            'student_session_id' => (int) $row['student_session_id'],
            'student_id' => (int) $row['student_id'],
            'admission_no' => $row['admission_no'] ?? '',
            'roll_no' => $row['roll_no'] ?? '',
            'firstname' => $row['firstname'] ?? '',
            'middlename' => $row['middlename'] ?? '',
            'lastname' => $row['lastname'] ?? '',
            'student_subject_attendance_id' => (int) $row['student_subject_attendance_id'],
            'attendence_type_id' => $row['attendence_type_id'] === null || $row['attendence_type_id'] === '' ? null : (int) $row['attendence_type_id'],
            'remark' => $row['remark'] ?? '',
        ];
    }

    $mysqli->close();
    at_json_out([
        'success' => true,
        'date' => $date,
        'subject_timetable_id' => $stid,
        'is_first_time_attendance' => $is_first,
        'students' => $students,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    at_json_out([
        'success' => false,
        'error' => $e->getMessage(),
        'students' => [],
        'is_first_time_attendance' => true,
    ]);
}
