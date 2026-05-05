<?php
/**
 * Attendance — student day attendance grid (admin stuattendence/index).
 * GET: class_id, section_id, date (YYYY-MM-DD)
 * Mirrors Stuattendence_model::searchAttendenceClassSection.
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

    $dEsc = $mysqli->real_escape_string($date);

    $sql = "SELECT student_sessions.in_time,student_sessions.out_time,student_sessions.attendence_id,student_sessions.attendence_dt,
        students.firstname,students.middlename,students.lastname,student_sessions.date,student_sessions.remark,student_sessions.feedback,
        student_sessions.biometric_attendence,student_sessions.qrcode_attendance,student_sessions.biometric_device_data,student_sessions.user_agent,
        students.roll_no,students.admission_no,students.id AS std_id,student_sessions.attendence_type_id,student_sessions.id AS student_session_id,
        attendence_type.type AS att_type,attendence_type.key_value AS type_key,attendence_type.long_lang_name,attendence_type.long_name_style
        FROM students,(SELECT student_attendences.in_time,student_attendences.out_time,
        student_session.id,student_session.student_id , IFNULL(student_attendences.date, 'xxx') AS date, IFNULL(student_attendences.created_at, 'xxx') AS attendence_dt,
        student_attendences.remark,student_attendences.feedback,student_attendences.biometric_attendence,student_attendences.user_agent,student_attendences.biometric_device_data,student_attendences.qrcode_attendance, IFNULL(student_attendences.id, 0) AS attendence_id,student_attendences.attendence_type_id
        FROM `student_session` LEFT JOIN student_attendences ON student_attendences.student_session_id=student_session.id AND student_attendences.date='" . $dEsc . "'
        WHERE student_session.session_id=" . $session_id . " AND student_session.class_id=" . $class_id . " AND student_session.section_id=" . $section_id . ") AS student_sessions
        LEFT JOIN attendence_type ON attendence_type.id=student_sessions.attendence_type_id
        WHERE student_sessions.student_id = students.id AND students.is_active = 'yes'
        ORDER BY students.admission_no ASC";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $rows = [];
    $is_first_time = true;
    while ($row = $res->fetch_assoc()) {
        $tid = $row['attendence_type_id'];
        if ($tid !== null && $tid !== '' && (int) $tid > 0) {
            $is_first_time = false;
        }
        $rows[] = [
            'student_session_id' => (int) $row['student_session_id'],
            'student_id' => (int) $row['std_id'],
            'admission_no' => $row['admission_no'] ?? '',
            'roll_no' => $row['roll_no'] ?? '',
            'firstname' => $row['firstname'] ?? '',
            'middlename' => $row['middlename'] ?? '',
            'lastname' => $row['lastname'] ?? '',
            'attendance_row_id' => (int) $row['attendence_id'],
            'attendence_type_id' => $row['attendence_type_id'] === null || $row['attendence_type_id'] === '' ? null : (int) $row['attendence_type_id'],
            'att_type' => $row['att_type'] ?? '',
            'type_key' => $row['type_key'] ?? '',
            'remark' => $row['remark'] ?? '',
            'feedback' => $row['feedback'] ?? '',
            'in_time' => $row['in_time'],
            'out_time' => $row['out_time'],
            'biometric_attendence' => isset($row['biometric_attendence']) ? (int) $row['biometric_attendence'] : 0,
            'qrcode_attendance' => isset($row['qrcode_attendance']) ? (int) $row['qrcode_attendance'] : 0,
        ];
    }

    $mysqli->close();
    at_json_out([
        'success' => true,
        'date' => $date,
        'is_first_time_attendance' => $is_first_time,
        'students' => $rows,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    at_json_out([
        'success' => false,
        'error' => $e->getMessage(),
        'date' => $date ?? '',
        'is_first_time_attendance' => true,
        'students' => [],
    ]);
}
