<?php
/**
 * Teacher timetable — daily or weekly.
 * GET: staff_id (required), day (optional English weekday e.g. Monday), api_secret optional.
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

    $staff_id = isset($_GET['staff_id']) ? (int) $_GET['staff_id'] : 0;
    if ($staff_id <= 0) {
        throw new Exception('staff_id is required.');
    }

    $day_raw = isset($_GET['day']) ? trim((string) $_GET['day']) : '';
    $day_order = ac_ordered_weekday_keys($mysqli);

    if ($day_raw !== '') {
        $day_esc = $mysqli->real_escape_string($day_raw);
        $out = ac_query_entries_sql(
            $mysqli,
            $session_id,
            "AND subject_timetable.staff_id = " . (int) $staff_id . "
             AND subject_timetable.day = '" . $day_esc . "'"
        );
        if (isset($out['error'])) {
            throw new Exception($out['error']);
        }
        $mysqli->close();
        ac_json_out(array(
            'success' => true,
            'session_id' => $session_id,
            'staff_id' => $staff_id,
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
            "AND subject_timetable.staff_id = " . (int) $staff_id . "
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
        'staff_id' => $staff_id,
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
        'staff_id' => 0,
        'day' => '',
        'day_order' => array(),
        'entries' => array(),
        'by_day' => null,
    ));
}
