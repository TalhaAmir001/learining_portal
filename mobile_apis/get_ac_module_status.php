<?php
/**
 * Academics — module status list (Portal 2 parity).
 *
 * This endpoint is used by the Flutter app to decide which tiles to show under
 * Academics. It mirrors the short_codes used by Portal 2's Webservice
 * getAcademicsModuleStatus().
 *
 * GET (optional): api_secret when AC_API_SECRET is set.
 */
require_once __DIR__ . '/ac_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    ac_require_api_secret(array_merge($_GET, array()));

    // Default to enabled: the Flutter app will still handle role gating.
    // If you later want DB-driven enable/disable, wire it here.
    $modules = array(
        array('name' => 'Class Timetable', 'short_code' => 'class_timetable', 'status' => 1),
        array('name' => 'Syllabus Status', 'short_code' => 'syllabus_status', 'status' => 1),
        array('name' => 'Attendance', 'short_code' => 'attendance', 'status' => 1),
        array('name' => 'Examinations', 'short_code' => 'examinations', 'status' => 1),
        array('name' => 'Student Timeline', 'short_code' => 'student_timeline', 'status' => 1),
        array('name' => 'My Documents', 'short_code' => 'mydocuments', 'status' => 1),
        array('name' => 'Behaviour Records', 'short_code' => 'behaviour_records', 'status' => 1),
        array('name' => 'CBSE Exam', 'short_code' => 'cbseexam', 'status' => 1),
    );

    $mysqli->close();
    ac_json_out(array(
        'success' => true,
        'module_list' => $modules,
    ));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    ac_json_out(array(
        'success' => false,
        'error' => $e->getMessage(),
        'module_list' => array(),
    ));
}

