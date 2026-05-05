<?php
/**
 * Room timetable — filter by subject_timetable.room_no.
 * GET: room_no (required), day (optional).
 */

require_once __DIR__ . '/ac_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    ac_require_api_secret(array_merge($_GET, array()));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $room_no = isset($_GET['room_no']) ? trim((string) $_GET['room_no']) : '';
    if ($room_no === '') {
        throw new Exception('room_no is required.');
    }

    $room_esc = $mysqli->real_escape_string($room_no);
    $day_raw = isset($_GET['day']) ? trim((string) $_GET['day']) : '';
    $day_order = ac_ordered_weekday_keys($mysqli);

    if ($day_raw !== '') {
        $day_esc = $mysqli->real_escape_string($day_raw);
        $out = ac_query_entries_sql(
            $mysqli,
            $session_id,
            "AND TRIM(subject_timetable.room_no) = '" . $room_esc . "'
             AND subject_timetable.day = '" . $day_esc . "'"
        );
        if (isset($out['error'])) {
            throw new Exception($out['error']);
        }
        $mysqli->close();
        ac_json_out(array(
            'success' => true,
            'session_id' => $session_id,
            'room_no' => $room_no,
            'day' => $day_raw,
            'day_order' => $day_order,
            'entries' => $out['entries'],
            'by_day' => null,
        ));
    }

    $by_day = array();
    foreach ($day_order as $dk) {
        $day_esc = $mysqli->real_escape_string($dk);
        $out = ac_query_entries_sql(
            $mysqli,
            $session_id,
            "AND TRIM(subject_timetable.room_no) = '" . $room_esc . "'
             AND subject_timetable.day = '" . $day_esc . "'"
        );
        if (isset($out['error'])) {
            throw new Exception($out['error']);
        }
        $by_day[$dk] = $out['entries'];
    }

    $mysqli->close();
    ac_json_out(array(
        'success' => true,
        'session_id' => $session_id,
        'room_no' => $room_no,
        'day' => '',
        'day_order' => $day_order,
        'entries' => array(),
        'by_day' => $by_day,
    ));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    ac_json_out(array(
        'success' => false,
        'error' => $e->getMessage(),
        'session_id' => 0,
        'room_no' => '',
        'day' => '',
        'day_order' => array(),
        'entries' => array(),
        'by_day' => null,
    ));
}
