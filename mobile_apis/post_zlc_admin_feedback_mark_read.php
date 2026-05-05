<?php
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $body = zlc_read_json_body();
    zlc_require_api_secret($body);
    $id = isset($body['id']) ? (int) $body['id'] : 0;
    $staff_id = isset($body['staff_id']) ? (int) $body['staff_id'] : 0;
    if ($id <= 0 || $staff_id <= 0) {
        throw new Exception('id and staff_id required');
    }
    $mysqli = zlc_mysqli_connect();
    $now = date('Y-m-d H:i:s');
    if (!$mysqli->query("UPDATE live_class_feedback SET read_at='" . $mysqli->real_escape_string($now) . "', read_by_staff_id=" . (int) $staff_id . ", updated_at='" . $mysqli->real_escape_string($now) . "' WHERE id=" . (int) $id)) {
        throw new Exception('Update failed: ' . $mysqli->error);
    }
    zlc_json_out(array('success' => true));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
