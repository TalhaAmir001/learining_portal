<?php
/**
 * Shared bootstrap for Zoom Live Classes (Conference) mobile APIs.
 * DB credentials mirror other mobile_apis in this project.
 */

if (!defined('ZLC_API_SECRET')) {
    $env = getenv('ZLC_API_SECRET');
    define('ZLC_API_SECRET', ($env !== false && $env !== '') ? (string) $env : '');
}

function zlc_json_out($data) {
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function zlc_mysqli_connect() {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        zlc_json_out(array('success' => false, 'error' => 'Database connection failed: ' . $mysqli->connect_error));
    }
    $mysqli->set_charset('utf8mb4');
    return $mysqli;
}

function zlc_current_session_id($mysqli) {
    $sr = $mysqli->query('SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1');
    if (!$sr || $sr->num_rows === 0) {
        return 0;
    }
    $row = $sr->fetch_assoc();
    return (int) $row['session_id'];
}

function zlc_require_api_secret($body) {
    if (ZLC_API_SECRET === '') {
        return;
    }
    $sent = '';
    if (is_array($body) && isset($body['api_secret'])) {
        $sent = (string) $body['api_secret'];
    }
    if ($sent === '' && !empty($_SERVER['HTTP_X_ZLC_SECRET'])) {
        $sent = (string) $_SERVER['HTTP_X_ZLC_SECRET'];
    }
    if (!hash_equals(ZLC_API_SECRET, $sent)) {
        zlc_json_out(array('success' => false, 'error' => 'Invalid or missing api_secret (set env ZLC_API_SECRET; send api_secret in JSON or X-ZLC-Secret header).'));
    }
}

function zlc_read_json_body() {
    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true);
    return is_array($body) ? $body : array();
}

function zlc_zoom_settings($mysqli) {
    $r = $mysqli->query('SELECT zoom_api_key, zoom_api_secret, use_teacher_api, use_zoom_app, use_zoom_app_user, parent_live_class FROM zoom_settings ORDER BY id ASC LIMIT 1');
    if (!$r || $r->num_rows === 0) {
        return null;
    }
    return $r->fetch_assoc();
}

function zlc_oauth_token_json($mysqli, $oauth_staff_id) {
    $oauth_staff_id = (int) $oauth_staff_id;
    $st = $mysqli->prepare('SELECT token_json FROM zoom_oauth_tokens WHERE staff_id = ? LIMIT 1');
    if (!$st) {
        return null;
    }
    $st->bind_param('i', $oauth_staff_id);
    $st->execute();
    $res = $st->get_result();
    if (!$res || $res->num_rows === 0) {
        return null;
    }
    $row = $res->fetch_assoc();
    return isset($row['token_json']) ? (string) $row['token_json'] : null;
}

function zlc_conference_row($mysqli, $conference_id) {
    $id = (int) $conference_id;
    if ($id <= 0) {
        return null;
    }
    $r = $mysqli->query('SELECT * FROM conferences WHERE id = ' . $id . ' LIMIT 1');
    if (!$r || $r->num_rows === 0) {
        return null;
    }
    return $r->fetch_assoc();
}

function zlc_conference_sections($mysqli, $conference_id) {
    $id = (int) $conference_id;
    $rows = array();
    $sql = 'SELECT cs.id, cs.cls_section_id, cs2.class_id, cs2.section_id, c.class AS class_name, s.section AS section_name
        FROM conference_sections cs
        INNER JOIN class_sections cs2 ON cs2.id = cs.cls_section_id
        INNER JOIN classes c ON c.id = cs2.class_id
        INNER JOIN sections s ON s.id = cs2.section_id
        WHERE cs.conference_id = ' . $id . '
        ORDER BY cs.id ASC';
    $res = $mysqli->query($sql);
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $rows[] = array(
                'id' => (int) $row['id'],
                'cls_section_id' => (int) $row['cls_section_id'],
                'class_id' => (int) $row['class_id'],
                'section_id' => (int) $row['section_id'],
                'class_name' => $row['class_name'],
                'section_name' => $row['section_name'],
            );
        }
    }
    return $rows;
}

function zlc_staff_zoom_credentials($mysqli, $staff_id) {
    $staff_id = (int) $staff_id;
    $r = $mysqli->query('SELECT id, zoom_api_key, zoom_api_secret FROM staff WHERE id = ' . $staff_id . ' LIMIT 1');
    if (!$r || $r->num_rows === 0) {
        return array('zoom_api_key' => '', 'zoom_api_secret' => '');
    }
    $row = $r->fetch_assoc();
    return array(
        'zoom_api_key' => isset($row['zoom_api_key']) ? (string) $row['zoom_api_key'] : '',
        'zoom_api_secret' => isset($row['zoom_api_secret']) ? (string) $row['zoom_api_secret'] : '',
    );
}

/**
 * Resolve Zoom OAuth client id/secret for an API call (global vs teacher self-app).
 */
/**
 * Mirror Conferencehistory_model::updatehistory for mobile (student or staff).
 */
function zlc_update_conference_history($mysqli, $conference_id, $type, $entity_id) {
    $conference_id = (int) $conference_id;
    $entity_id = (int) $entity_id;
    if ($conference_id <= 0 || $entity_id <= 0) {
        return false;
    }
    if ($type === 'student') {
        $sql = 'SELECT id, total_hit FROM conferences_history WHERE conference_id = ' . $conference_id . ' AND student_id = ' . $entity_id . ' LIMIT 1';
    } elseif ($type === 'staff') {
        $sql = 'SELECT id, total_hit FROM conferences_history WHERE conference_id = ' . $conference_id . ' AND staff_id = ' . $entity_id . ' LIMIT 1';
    } else {
        return false;
    }
    $res = $mysqli->query($sql);
    if ($res && $res->num_rows > 0) {
        $row = $res->fetch_assoc();
        $id = (int) $row['id'];
        $hit = (int) $row['total_hit'] + 1;
        return $mysqli->query('UPDATE conferences_history SET total_hit = ' . $hit . ' WHERE id = ' . $id);
    }
    if ($type === 'student') {
        return $mysqli->query('INSERT INTO conferences_history (conference_id, student_id, total_hit) VALUES (' . $conference_id . ', ' . $entity_id . ', 1)');
    }
    return $mysqli->query('INSERT INTO conferences_history (conference_id, staff_id, total_hit) VALUES (' . $conference_id . ', ' . $entity_id . ', 1)');
}

function zlc_student_can_access_conference($mysqli, $student_id, $conference_id, $session_id) {
    $student_id = (int) $student_id;
    $conference_id = (int) $conference_id;
    $session_id = (int) $session_id;
    if ($student_id < 1 || $conference_id < 1 || $session_id < 1) {
        return false;
    }
    $live = zlc_conference_row($mysqli, $conference_id);
    if (!$live) {
        return false;
    }
    if (!empty($live['class_id']) && !empty($live['section_id'])) {
        $sql = 'SELECT id FROM student_session WHERE student_id=' . $student_id . ' AND class_id=' . (int) $live['class_id'] . ' AND section_id=' . (int) $live['section_id'] . ' AND session_id=' . $session_id . ' LIMIT 1';
        $r = $mysqli->query($sql);
        if ($r && $r->num_rows > 0) {
            return true;
        }
    }
    $secs = zlc_conference_sections($mysqli, $conference_id);
    foreach ($secs as $s) {
        $cid = (int) $s['class_id'];
        $sid = (int) $s['section_id'];
        $sql = 'SELECT id FROM student_session WHERE student_id=' . $student_id . ' AND class_id=' . $cid . ' AND section_id=' . $sid . ' AND session_id=' . $session_id . ' LIMIT 1';
        $r = $mysqli->query($sql);
        if ($r && $r->num_rows > 0) {
            return true;
        }
    }
    $sql = 'SELECT id FROM conferences_history WHERE conference_id=' . $conference_id . ' AND student_id=' . $student_id . ' LIMIT 1';
    $r = $mysqli->query($sql);
    return $r && $r->num_rows > 0;
}

function zlc_resolve_zoom_client($mysqli, $oauth_staff_id) {
    $settings = zlc_zoom_settings($mysqli);
    if (!$settings) {
        return array('ok' => false, 'error' => 'zoom_settings missing');
    }
    $oauth_staff_id = (int) $oauth_staff_id;
    $use_teacher = !empty($settings['use_teacher_api']);
    if ($use_teacher && $oauth_staff_id > 0) {
        $c = zlc_staff_zoom_credentials($mysqli, $oauth_staff_id);
        if ($c['zoom_api_key'] !== '' && $c['zoom_api_secret'] !== '') {
            return array('ok' => true, 'client_id' => $c['zoom_api_key'], 'client_secret' => $c['zoom_api_secret'], 'oauth_staff_id' => $oauth_staff_id);
        }
    }
    return array(
        'ok' => true,
        'client_id' => (string) $settings['zoom_api_key'],
        'client_secret' => (string) $settings['zoom_api_secret'],
        'oauth_staff_id' => 0,
    );
}
