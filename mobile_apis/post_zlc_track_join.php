<?php
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $body = zlc_read_json_body();
    zlc_require_api_secret($body);
    $conference_id = isset($body['conference_id']) ? (int) $body['conference_id'] : 0;
    $student_id = isset($body['student_id']) ? (int) $body['student_id'] : 0;
    $staff_id = isset($body['staff_id']) ? (int) $body['staff_id'] : 0;
    if ($conference_id <= 0) {
        throw new Exception('conference_id required');
    }
    $mysqli = zlc_mysqli_connect();
    $live = zlc_conference_row($mysqli, $conference_id);
    if (!$live) {
        throw new Exception('Conference not found');
    }
    $created_id = isset($live['created_id']) ? (int) $live['created_id'] : 0;
    if ($student_id > 0) {
        zlc_update_conference_history($mysqli, $conference_id, 'student', $student_id);
    } elseif ($staff_id > 0) {
        if ($staff_id === $created_id) {
            zlc_json_out(array('success' => true, 'skipped' => true));
        }
        zlc_update_conference_history($mysqli, $conference_id, 'staff', $staff_id);
    } else {
        throw new Exception('student_id or staff_id required');
    }
    zlc_json_out(array('success' => true));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
