<?php
require_once __DIR__ . '/zlc_bootstrap.php';
require_once __DIR__ . '/zlc_zoom_lib.php';

try {
    $body = zlc_read_json_body();
    zlc_require_api_secret($body);
    $conference_id = isset($body['conference_id']) ? (int) $body['conference_id'] : 0;
    $oauth_staff_id = isset($body['oauth_staff_id']) ? (int) $body['oauth_staff_id'] : 0;
    $force = !empty($body['force_delete']);
    if ($conference_id <= 0) {
        throw new Exception('conference_id required');
    }
    $mysqli = zlc_mysqli_connect();
    $row = zlc_conference_row($mysqli, $conference_id);
    if (!$row) {
        throw new Exception('Conference not found');
    }
    $meeting_id = '';
    if (!empty($row['return_response'])) {
        $j = json_decode($row['return_response'], true);
        if (is_array($j) && isset($j['id'])) {
            $meeting_id = (string) $j['id'];
        }
    }
    if ($meeting_id !== '' && !$force) {
        $api_type = isset($row['api_type']) ? (string) $row['api_type'] : 'global';
        $oauth = 0;
        if ($api_type !== 'global') {
            $created_id = isset($row['created_id']) ? (int) $row['created_id'] : 0;
            $oauth = $oauth_staff_id > 0 ? $oauth_staff_id : $created_id;
        }
        $del = zlc_zoom_delete_meeting($mysqli, $oauth, $meeting_id);
        if (empty($del['ok'])) {
            throw new Exception($del['error']);
        }
    }
    $mysqli->query('DELETE FROM conference_staff WHERE conference_id=' . (int) $conference_id);
    if (!$mysqli->query('DELETE FROM conferences WHERE id=' . (int) $conference_id)) {
        throw new Exception('Delete failed: ' . $mysqli->error);
    }
    zlc_json_out(array('success' => true));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
