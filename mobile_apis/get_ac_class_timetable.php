<?php
/**
 * Class-section timetable — daily or weekly.
 * GET: class_id, section_id (required), day (optional).
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

    $class_id = isset($_GET['class_id']) ? (int) $_GET['class_id'] : 0;
    $section_id = isset($_GET['section_id']) ? (int) $_GET['section_id'] : 0;
    if ($class_id <= 0 || $section_id <= 0) {
        throw new Exception('class_id and section_id are required.');
    }

    $day_raw = isset($_GET['day']) ? trim((string) $_GET['day']) : '';
    $day_order = ac_ordered_weekday_keys($mysqli);

    if ($day_raw !== '') {
        $day_esc = $mysqli->real_escape_string($day_raw);
        $out = ac_query_entries_sql(
            $mysqli,
            $session_id,
            "AND subject_timetable.class_id = " . (int) $class_id . "
             AND subject_timetable.section_id = " . (int) $section_id . "
             AND subject_timetable.day = '" . $day_esc . "'"
        );
        if (isset($out['error'])) {
            throw new Exception($out['error']);
        }
        $mysqli->close();
        ac_json_out(array(
            'success' => true,
            'session_id' => $session_id,
            'class_id' => $class_id,
            'section_id' => $section_id,
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
            "AND subject_timetable.class_id = " . (int) $class_id . "
             AND subject_timetable.section_id = " . (int) $section_id . "
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
        'class_id' => $class_id,
        'section_id' => $section_id,
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
        'class_id' => 0,
        'section_id' => 0,
        'day' => '',
        'day_order' => array(),
        'entries' => array(),
        'by_day' => null,
    ));
}
