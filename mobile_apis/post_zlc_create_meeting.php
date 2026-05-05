<?php
require_once __DIR__ . '/zlc_bootstrap.php';
require_once __DIR__ . '/zlc_zoom_lib.php';

try {
    $body = zlc_read_json_body();
    zlc_require_api_secret($body);
    $oauth_staff_id = isset($body['oauth_staff_id']) ? (int) $body['oauth_staff_id'] : 0;
    $title = isset($body['title']) ? trim((string) $body['title']) : '';
    $date_in = isset($body['date']) ? trim((string) $body['date']) : '';
    $duration = isset($body['duration']) ? (int) $body['duration'] : 0;
    $password = isset($body['password']) ? (string) $body['password'] : '';
    $host_video = !empty($body['host_video']) ? 1 : 0;
    $client_video = !empty($body['client_video']) ? 1 : 0;
    $description = isset($body['description']) ? (string) $body['description'] : '';
    $timezone = isset($body['timezone']) ? (string) $body['timezone'] : 'UTC';
    $created_id = isset($body['created_id']) ? (int) $body['created_id'] : 0;
    $staff_ids = isset($body['staff_ids']) && is_array($body['staff_ids']) ? $body['staff_ids'] : array();
    if ($title === '' || $date_in === '' || $duration <= 0 || $created_id <= 0) {
        throw new Exception('title, date, duration, created_id required');
    }
    $ts = strtotime($date_in);
    if ($ts === false) {
        throw new Exception('Invalid date');
    }
    $date_sql = date('Y-m-d H:i:s', $ts);
    $mysqli = zlc_mysqli_connect();
    $session_id = zlc_current_session_id($mysqli);
    $settings = zlc_zoom_settings($mysqli);
    $api_type = 'global';
    if ($settings && !empty($settings['use_teacher_api'])) {
        $creds = zlc_staff_zoom_credentials($mysqli, $oauth_staff_id > 0 ? $oauth_staff_id : $created_id);
        if ($creds['zoom_api_key'] !== '' && $creds['zoom_api_secret'] !== '') {
            $api_type = 'self';
        }
    }
    $insert_for_api = array(
        'title' => $title,
        'date' => $date_sql,
        'duration' => $duration,
        'password' => $password,
        'host_video' => $host_video,
        'client_video' => $client_video,
        'description' => $description,
        'timezone' => $timezone,
    );
    $zoom = zlc_zoom_create_meeting($mysqli, $oauth_staff_id > 0 ? $oauth_staff_id : ($api_type === 'self' ? $created_id : 0), $insert_for_api);
    if (empty($zoom['ok'])) {
        throw new Exception($zoom['error']);
    }
    $data = $zoom['data'];
    $mysqli->begin_transaction();
    $ret = $mysqli->real_escape_string(json_encode($data));
    $titleEsc = $mysqli->real_escape_string($title);
    $pwdEsc = $mysqli->real_escape_string($password);
    $descEsc = $mysqli->real_escape_string($description);
    $tzEsc = $mysqli->real_escape_string($timezone);
    $sql = "INSERT INTO conferences (staff_id, title, `date`, duration, password, created_id, api_type, host_video, client_video, description, timezone, return_response, session_id, purpose, status)
        VALUES (" . (int) $created_id . ", '" . $titleEsc . "', '" . $date_sql . "', " . (int) $duration . ", '" . $pwdEsc . "', " . (int) $created_id . ", '" . $mysqli->real_escape_string($api_type) . "', " . (int) $host_video . ", " . (int) $client_video . ", '" . $descEsc . "', '" . $tzEsc . "', '" . $ret . "', " . (int) $session_id . ", 'meeting', 0)";
    if (!$mysqli->query($sql)) {
        throw new Exception('Insert conference failed: ' . $mysqli->error);
    }
    $newId = (int) $mysqli->insert_id;
    foreach ($staff_ids as $sid) {
        $sid = (int) $sid;
        if ($sid <= 0) {
            continue;
        }
        $mysqli->query('INSERT INTO conference_staff (conference_id, staff_id) VALUES (' . $newId . ', ' . $sid . ')');
    }
    $mysqli->commit();
    zlc_json_out(array('success' => true, 'conference_id' => $newId));
} catch (Exception $e) {
    if (isset($mysqli) && $mysqli instanceof mysqli) {
        @$mysqli->rollback();
    }
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
