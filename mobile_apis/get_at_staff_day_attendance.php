<?php
/**
 * Attendance — staff list with attendance for a role + date (admin staffattendance/index).
 * GET: role (roles.name, e.g. Teacher), date (YYYY-MM-DD)
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

    $role = isset($_GET['role']) ? trim((string) $_GET['role']) : '';
    $date = isset($_GET['date']) ? trim((string) $_GET['date']) : '';
    if ($role === '' || !at_valid_date($date)) {
        throw new Exception('role and valid date (YYYY-MM-DD) are required.');
    }

    $roleEsc = $mysqli->real_escape_string($role);
    $dEsc = $mysqli->real_escape_string($date);

    $sql = "SELECT staff_attendance.staff_attendance_type_id,
            staff_attendance.in_time, staff_attendance.out_time,
            staff_attendance.remark,
            IFNULL(staff_attendance.id, 0) AS attendance_row_id,
            staff.id AS staff_id,
            staff.name, staff.surname, staff.employee_id, staff.email, staff.contact_no,
            roles.name AS role_name,
            staff_attendance_type.type AS att_type,
            staff_attendance_type.key_value AS type_key
            FROM staff
            LEFT JOIN staff_roles ON staff.id = staff_roles.staff_id
            LEFT JOIN roles ON roles.id = staff_roles.role_id
            LEFT JOIN staff_attendance ON staff.id = staff_attendance.staff_id AND staff_attendance.date = '" . $dEsc . "'
            LEFT JOIN staff_attendance_type ON staff_attendance_type.id = staff_attendance.staff_attendance_type_id
            WHERE roles.name = '" . $roleEsc . "' AND staff.is_active = 1
            ORDER BY staff.surname ASC, staff.name ASC";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $rows = [];
    $is_first = true;
    while ($row = $res->fetch_assoc()) {
        $tid = $row['staff_attendance_type_id'];
        if ($tid !== null && $tid !== '' && (int) $tid > 0) {
            $is_first = false;
        }
        $rows[] = [
            'staff_id' => (int) $row['staff_id'],
            'name' => trim(($row['name'] ?? '') . ' ' . ($row['surname'] ?? '')),
            'employee_id' => $row['employee_id'] ?? '',
            'email' => $row['email'] ?? '',
            'contact_no' => $row['contact_no'] ?? '',
            'role_name' => $row['role_name'] ?? '',
            'attendance_row_id' => (int) $row['attendance_row_id'],
            'staff_attendance_type_id' => $row['staff_attendance_type_id'] === null || $row['staff_attendance_type_id'] === ''
                ? null : (int) $row['staff_attendance_type_id'],
            'att_type' => $row['att_type'] ?? '',
            'type_key' => $row['type_key'] ?? '',
            'remark' => $row['remark'] ?? '',
            'in_time' => $row['in_time'],
            'out_time' => $row['out_time'],
        ];
    }

    $mysqli->close();
    at_json_out([
        'success' => true,
        'date' => $date,
        'role' => $role,
        'is_first_time_attendance' => $is_first,
        'staff' => $rows,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    at_json_out([
        'success' => false,
        'error' => $e->getMessage(),
        'staff' => [],
        'is_first_time_attendance' => true,
    ]);
}
