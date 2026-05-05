<?php
/**
 * GET: student_id, conference_id
 */
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $student_id = isset($_GET['student_id']) ? (int) $_GET['student_id'] : 0;
    $conference_id = isset($_GET['conference_id']) ? (int) $_GET['conference_id'] : 0;
    if ($student_id <= 0 || $conference_id <= 0) {
        throw new Exception('student_id and conference_id required');
    }
    $mysqli = zlc_mysqli_connect();
    $session_id = zlc_current_session_id($mysqli);
    $allowed = zlc_student_can_access_conference($mysqli, $student_id, $conference_id, $session_id);
    $existing = null;
    $res = $mysqli->query('SELECT * FROM live_class_feedback WHERE student_id=' . (int) $student_id . ' AND conference_id=' . (int) $conference_id . ' LIMIT 1');
    if ($res && $res->num_rows > 0) {
        $existing = $res->fetch_assoc();
    }
    zlc_json_out(array(
        'success' => true,
        'can_submit' => $allowed,
        'feedback' => $existing,
        'session_id' => $session_id,
    ));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
