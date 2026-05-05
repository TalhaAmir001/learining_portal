<?php
/**
 * Shared bootstrap for Academics (timetable) mobile APIs.
 */

if (!defined('AC_API_SECRET')) {
    $env = getenv('AC_API_SECRET');
    define('AC_API_SECRET', ($env !== false && $env !== '') ? (string) $env : '');
}

function ac_json_out($data) {
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function ac_mysqli_connect() {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        ac_json_out(array('success' => false, 'error' => 'Database connection failed: ' . $mysqli->connect_error));
    }
    $mysqli->set_charset('utf8mb4');
    return $mysqli;
}

function ac_current_session_id($mysqli) {
    $sr = $mysqli->query('SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1');
    if (!$sr || $sr->num_rows === 0) {
        return 0;
    }
    $row = $sr->fetch_assoc();
    return (int) $row['session_id'];
}

/**
 * Portal Customlib::getDaysname() order: 7 days starting from sch_settings.start_week (e.g. Monday).
 *
 * @return string[] English weekday names in display order.
 */
function ac_ordered_weekday_keys($mysqli) {
    $start_week = 'Monday';
    $col = $mysqli->query("SHOW COLUMNS FROM sch_settings LIKE 'start_week'");
    if ($col && $col->num_rows > 0) {
        $r = $mysqli->query('SELECT start_week FROM sch_settings ORDER BY id ASC LIMIT 1');
        if ($r && $r->num_rows > 0) {
            $sw = trim((string) $r->fetch_assoc()['start_week']);
            if ($sw !== '') {
                $start_week = $sw;
            }
        }
    }
    $start = strtotime('last week ' . $start_week);
    if ($start === false) {
        $start = strtotime('last week Monday');
    }
    $end = $start + (86400 * 7);
    $out = array();
    for ($i = $start; $i < $end; $i += 86400) {
        $out[] = date('l', $i);
    }
    return $out;
}

function ac_read_json_body() {
    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true);
    return is_array($body) ? $body : array();
}

function ac_require_api_secret($body) {
    if (AC_API_SECRET === '') {
        return;
    }
    $sent = '';
    if (is_array($body) && isset($body['api_secret'])) {
        $sent = (string) $body['api_secret'];
    }
    if ($sent === '' && !empty($_SERVER['HTTP_X_AC_SECRET'])) {
        $sent = (string) $_SERVER['HTTP_X_AC_SECRET'];
    }
    if ($sent === '' && isset($_GET['api_secret'])) {
        $sent = (string) $_GET['api_secret'];
    }
    if (!hash_equals(AC_API_SECRET, $sent)) {
        ac_json_out(array('success' => false, 'error' => 'Invalid or missing api_secret (set env AC_API_SECRET; send api_secret in JSON/query or X-AC-Secret header).'));
    }
}

/** Mirror Portal Customlib::timeFormat($time, true) → H:i */
function ac_portal_start_time($time_from) {
    $time_from = trim((string) $time_from);
    if ($time_from === '') {
        return '';
    }
    $ts = strtotime($time_from);
    if ($ts === false) {
        return '';
    }
    return date('H:i', $ts);
}

function ac_time_to_minutes($hms) {
    $hms = trim((string) $hms);
    if ($hms === '') {
        return null;
    }
    $parts = explode(':', $hms);
    if (count($parts) < 2) {
        return null;
    }
    $h = (int) $parts[0];
    $m = (int) $parts[1];
    return $h * 60 + $m;
}

/**
 * Build one timetable row for JSON (class / teacher / room / subject views).
 */
function ac_map_timetable_row($row) {
    return array(
        'id' => (int) $row['id'],
        'subject_timetable_id' => (int) $row['id'],
        'class_id' => (int) $row['class_id'],
        'section_id' => (int) $row['section_id'],
        'class_name' => isset($row['class_name']) ? (string) $row['class_name'] : '',
        'section_name' => isset($row['section_name']) ? (string) $row['section_name'] : '',
        'subject_id' => (int) (isset($row['subject_id']) ? $row['subject_id'] : 0),
        'subject_name' => isset($row['subject_name']) ? (string) $row['subject_name'] : '',
        'subject_code' => isset($row['subject_code']) ? (string) $row['subject_code'] : (isset($row['code']) ? (string) $row['code'] : ''),
        'staff_id' => (int) (isset($row['staff_id']) ? $row['staff_id'] : 0),
        'staff_firstname' => isset($row['staff_firstname']) ? (string) $row['staff_firstname'] : (isset($row['name']) ? (string) $row['name'] : ''),
        'staff_surname' => isset($row['staff_surname']) ? (string) $row['staff_surname'] : (isset($row['surname']) ? (string) $row['surname'] : ''),
        'employee_id' => isset($row['employee_id']) ? (string) $row['employee_id'] : '',
        'day' => isset($row['day']) ? (string) $row['day'] : '',
        'time_from' => isset($row['time_from']) ? (string) $row['time_from'] : '',
        'time_to' => isset($row['time_to']) ? (string) $row['time_to'] : '',
        'start_time' => isset($row['start_time']) ? (string) $row['start_time'] : '',
        'end_time' => isset($row['end_time']) ? (string) $row['end_time'] : '',
        'room_no' => isset($row['room_no']) ? (string) $row['room_no'] : '',
        'subject_group_subject_id' => (int) (isset($row['subject_group_subject_id']) ? $row['subject_group_subject_id'] : 0),
        'subject_group_id' => (int) (isset($row['subject_group_id']) ? $row['subject_group_id'] : 0),
    );
}

function ac_select_timetable_from_joins() {
    return "SELECT
            subject_timetable.id,
            subject_timetable.class_id,
            subject_timetable.section_id,
            subject_timetable.staff_id,
            subject_timetable.day,
            subject_timetable.time_from,
            subject_timetable.time_to,
            subject_timetable.start_time,
            subject_timetable.end_time,
            subject_timetable.room_no,
            subject_timetable.session_id,
            subject_timetable.subject_group_subject_id,
            subject_timetable.subject_group_id,
            classes.class AS class_name,
            sections.section AS section_name,
            subject_group_subjects.subject_id AS subject_id,
            subj.name AS subject_name,
            subj.code AS subject_code,
            staff.name AS staff_firstname,
            staff.surname AS staff_surname,
            staff.employee_id AS employee_id
        FROM subject_timetable
        INNER JOIN classes ON classes.id = subject_timetable.class_id
        INNER JOIN sections ON sections.id = subject_timetable.section_id
        INNER JOIN subject_group_subjects ON subject_group_subjects.id = subject_timetable.subject_group_subject_id
        INNER JOIN subjects AS subj ON subj.id = subject_group_subjects.subject_id
        INNER JOIN staff ON staff.id = subject_timetable.staff_id";
}

function ac_query_entries_sql($mysqli, $session_id, $extra_where_sql) {
    $sql = ac_select_timetable_from_joins() . "
        WHERE subject_timetable.session_id = " . (int) $session_id . "
          AND staff.is_active = 1
          " . $extra_where_sql . "
        ORDER BY subject_timetable.start_time ASC";
    $res = $mysqli->query($sql);
    if (!$res) {
        return array('error' => 'Query failed: ' . $mysqli->error, 'entries' => array());
    }
    $rows = array();
    while ($row = $res->fetch_assoc()) {
        $rows[] = ac_map_timetable_row($row);
    }
    return array('entries' => $rows);
}

/**
 * Return true if new slot overlaps existing (same class/section/day/session), excluding $exclude_id.
 */
function ac_has_overlap($mysqli, $session_id, $class_id, $section_id, $day_esc, $start_min, $end_min, $exclude_id) {
    if ($start_min === null || $end_min === null || $end_min <= $start_min) {
        return false;
    }
    $q = "SELECT id, start_time, end_time FROM subject_timetable
        WHERE session_id = " . (int) $session_id . "
          AND class_id = " . (int) $class_id . "
          AND section_id = " . (int) $section_id . "
          AND day = '" . $day_esc . "'";
    if ($exclude_id > 0) {
        $q .= " AND id <> " . (int) $exclude_id;
    }
    $res = $mysqli->query($q);
    if (!$res) {
        return true;
    }
    while ($row = $res->fetch_assoc()) {
        $a = ac_time_to_minutes($row['start_time']);
        $b = ac_time_to_minutes($row['end_time']);
        if ($a === null || $b === null) {
            continue;
        }
        if ($start_min < $b && $end_min > $a) {
            return true;
        }
    }
    return false;
}
