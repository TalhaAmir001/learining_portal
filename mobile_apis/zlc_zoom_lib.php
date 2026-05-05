<?php
/**
 * Minimal Zoom REST + OAuth (curl) for mobile_apis (no CodeIgniter).
 */

function zlc_zoom_http_json($method, $url, $headers = array(), $body = null) {
    $ch = curl_init($url);
    $h = array();
    foreach ($headers as $k => $v) {
        $h[] = $k . ': ' . $v;
    }
    curl_setopt_array($ch, array(
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 60,
        CURLOPT_HTTPHEADER => $h,
    ));
    if ($body !== null && ($method === 'POST' || $method === 'PATCH' || $method === 'PUT')) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, is_string($body) ? $body : json_encode($body));
    }
    $raw = curl_exec($ch);
    $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);
    if ($err) {
        return array('http' => 0, 'err' => $err, 'json' => null, 'raw' => $raw);
    }
    $json = json_decode((string) $raw, true);
    return array('http' => $code, 'err' => '', 'json' => is_array($json) ? $json : null, 'raw' => (string) $raw);
}

function zlc_zoom_refresh_token($client_id, $client_secret, $refresh_token) {
    $auth = base64_encode($client_id . ':' . $client_secret);
    $url = 'https://zoom.us/oauth/token';
    $body = http_build_query(array(
        'grant_type' => 'refresh_token',
        'refresh_token' => $refresh_token,
    ));
    return zlc_zoom_http_json('POST', $url, array(
        'Authorization' => 'Basic ' . $auth,
        'Content-Type' => 'application/x-www-form-urlencoded',
    ), $body);
}

function zlc_zoom_save_oauth($mysqli, $oauth_staff_id, $token_array) {
    $oauth_staff_id = (int) $oauth_staff_id;
    $json = json_encode($token_array);
    $now = date('Y-m-d H:i:s');
    $st = $mysqli->prepare('INSERT INTO zoom_oauth_tokens (staff_id, token_json, updated_at) VALUES (?,?,?) ON DUPLICATE KEY UPDATE token_json=VALUES(token_json), updated_at=VALUES(updated_at)');
    if (!$st) {
        return false;
    }
    $st->bind_param('iss', $oauth_staff_id, $json, $now);
    return $st->execute();
}

function zlc_zoom_get_valid_access_token($mysqli, $oauth_staff_id) {
    $client = zlc_resolve_zoom_client($mysqli, $oauth_staff_id);
    if (empty($client['ok'])) {
        return array('ok' => false, 'error' => $client['error']);
    }
    $cid = $client['client_id'];
    $csec = $client['client_secret'];
    $rowKey = (int) $client['oauth_staff_id'];
    $raw = zlc_oauth_token_json($mysqli, $rowKey);
    if ($raw === null || $raw === '') {
        return array('ok' => false, 'error' => 'Zoom OAuth token not stored. Authorize Zoom in web admin (Conference) first.');
    }
    $tok = json_decode($raw, true);
    if (!is_array($tok) || empty($tok['access_token'])) {
        return array('ok' => false, 'error' => 'Stored Zoom token invalid.');
    }
    $access = (string) $tok['access_token'];
    return array('ok' => true, 'access_token' => $access, 'token' => $tok, 'raw_json' => $raw, 'client_id' => $cid, 'client_secret' => $csec, 'row_key' => $rowKey);
}

function zlc_zoom_try_refresh($mysqli, $row_key, $client_id, $client_secret, $refresh_token) {
    $r = zlc_zoom_refresh_token($client_id, $client_secret, $refresh_token);
    if ($r['http'] !== 200 || !is_array($r['json']) || empty($r['json']['access_token'])) {
        return false;
    }
    zlc_zoom_save_oauth($mysqli, $row_key, $r['json']);
    return (string) $r['json']['access_token'];
}

function zlc_zoom_create_meeting($mysqli, $oauth_staff_id, $insert_for_api) {
    $t = zlc_zoom_get_valid_access_token($mysqli, $oauth_staff_id);
    if (empty($t['ok'])) {
        return array('ok' => false, 'error' => $t['error']);
    }
    $access = $t['access_token'];
    $rowKey = (int) $t['row_key'];
    $cid = $t['client_id'];
    $csec = $t['client_secret'];
    $post_time = $insert_for_api['date'];
    $start_time = date('Y-m-d\TH:i:s', strtotime($post_time));
    $payload = array(
        'topic' => $insert_for_api['title'],
        'type' => 2,
        'start_time' => $start_time,
        'timezone' => $insert_for_api['timezone'],
        'password' => isset($insert_for_api['password']) ? (string) $insert_for_api['password'] : '',
        'duration' => (int) $insert_for_api['duration'],
        'agenda' => isset($insert_for_api['description']) ? (string) $insert_for_api['description'] : '',
        'settings' => array(
            'host_video' => !empty($insert_for_api['host_video']),
            'participant_video' => !empty($insert_for_api['client_video']),
            'join_before_host' => false,
            'mute_upon_entry' => false,
            'waiting_room' => false,
        ),
    );
    $url = 'https://api.zoom.us/v2/users/me/meetings';
    $res = zlc_zoom_http_json('POST', $url, array(
        'Authorization' => 'Bearer ' . $access,
        'Content-Type' => 'application/json',
    ), $payload);
    if ($res['http'] === 401 && is_array($t['token']) && !empty($t['token']['refresh_token'])) {
        $newAccess = zlc_zoom_try_refresh($mysqli, $rowKey, $cid, $csec, (string) $t['token']['refresh_token']);
        if ($newAccess) {
            $res = zlc_zoom_http_json('POST', $url, array(
                'Authorization' => 'Bearer ' . $newAccess,
                'Content-Type' => 'application/json',
            ), $payload);
        }
    }
    if ($res['http'] === 201 && is_array($res['json'])) {
        return array('ok' => true, 'data' => $res['json']);
    }
    $msg = is_array($res['json']) && isset($res['json']['message']) ? (string) $res['json']['message'] : ('HTTP ' . $res['http'] . ' ' . $res['raw']);
    return array('ok' => false, 'error' => $msg);
}

function zlc_zoom_delete_meeting($mysqli, $oauth_staff_id, $meeting_id) {
    $meeting_id = trim((string) $meeting_id);
    if ($meeting_id === '') {
        return array('ok' => false, 'error' => 'Missing meeting id');
    }
    $t = zlc_zoom_get_valid_access_token($mysqli, $oauth_staff_id);
    if (empty($t['ok'])) {
        return array('ok' => false, 'error' => $t['error']);
    }
    $access = $t['access_token'];
    $rowKey = (int) $t['row_key'];
    $cid = $t['client_id'];
    $csec = $t['client_secret'];
    $url = 'https://api.zoom.us/v2/meetings/' . rawurlencode($meeting_id);
    $res = zlc_zoom_http_json('DELETE', $url, array(
        'Authorization' => 'Bearer ' . $access,
    ), null);
    if ($res['http'] === 401 && is_array($t['token']) && !empty($t['token']['refresh_token'])) {
        $newAccess = zlc_zoom_try_refresh($mysqli, $rowKey, $cid, $csec, (string) $t['token']['refresh_token']);
        if ($newAccess) {
            $res = zlc_zoom_http_json('DELETE', $url, array(
                'Authorization' => 'Bearer ' . $newAccess,
            ), null);
        }
    }
    if ($res['http'] === 204) {
        return array('ok' => true);
    }
    $msg = is_array($res['json']) && isset($res['json']['message']) ? (string) $res['json']['message'] : ('HTTP ' . $res['http']);
    return array('ok' => false, 'error' => $msg);
}
