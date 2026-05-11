<?php
/**
 * Shared bootstrap for Smart Monitoring mobile APIs (Super Admin only).
 *
 * Mirrors the access rule in admin/Smartmonitoring.php (`_is_super_admin()`):
 * the caller must hold a staff_roles row whose role name equals "super admin"
 * (case-insensitive). Anything else is rejected with HTTP 200 + JSON error so
 * the Flutter app can surface a friendly message.
 *
 * Period values are validated as YYYY-MM-DD strings (matches the admin
 * controller). Default period = last 30 days.
 */

if (!defined('SM_API_SECRET')) {
    $env = getenv('SM_API_SECRET');
    define('SM_API_SECRET', ($env !== false && $env !== '') ? (string) $env : '');
}

function sm_json_out($data) {
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response']);
    } else {
        echo $json;
    }
    exit;
}

function sm_mysqli_connect() {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        sm_json_out(['success' => false, 'error' => 'Database connection failed: ' . $mysqli->connect_error]);
    }
    $mysqli->set_charset('utf8mb4');
    return $mysqli;
}

function sm_read_json_body() {
    $raw  = file_get_contents('php://input');
    $body = json_decode($raw, true);
    if (is_array($body)) {
        return $body;
    }
    return is_array($_POST) ? $_POST : [];
}

function sm_require_api_secret($body) {
    if (SM_API_SECRET === '') {
        return;
    }
    $sent = '';
    if (is_array($body) && isset($body['api_secret'])) {
        $sent = (string) $body['api_secret'];
    }
    if ($sent === '' && !empty($_SERVER['HTTP_X_SM_SECRET'])) {
        $sent = (string) $_SERVER['HTTP_X_SM_SECRET'];
    }
    if ($sent === '' && isset($_GET['api_secret'])) {
        $sent = (string) $_GET['api_secret'];
    }
    if (!hash_equals(SM_API_SECRET, $sent)) {
        sm_json_out(['success' => false, 'error' => 'Invalid or missing api_secret.']);
    }
}

function sm_current_session_id($mysqli) {
    $sr = $mysqli->query('SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1');
    if (!$sr || $sr->num_rows === 0) {
        return 0;
    }
    $row = $sr->fetch_assoc();
    return (int) $row['session_id'];
}

/** Validate a YYYY-MM-DD string. */
function sm_is_valid_date($d) {
    return (bool) preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $d);
}

/**
 * Resolve the [date_from, date_to] period for this request, applying the same
 * defaults / swap rules as admin/Smartmonitoring.php.
 *
 * @return array{0:string,1:string} [date_from, date_to]
 */
function sm_resolve_period($body) {
    $default_to   = date('Y-m-d');
    $default_from = date('Y-m-d', strtotime('-30 days'));

    $df = isset($body['date_from']) ? trim((string) $body['date_from']) : '';
    $dt = isset($body['date_to'])   ? trim((string) $body['date_to'])   : '';

    if (!sm_is_valid_date($df)) {
        $df = $default_from;
    }
    if (!sm_is_valid_date($dt)) {
        $dt = $default_to;
    }
    if ($df > $dt) {
        $tmp = $df;
        $df  = $dt;
        $dt  = $tmp;
    }
    return [$df, $dt];
}

/**
 * Verify the caller is a Super Admin. Terminates the request with a JSON
 * error if not. Mirrors `_is_super_admin()` in admin/Smartmonitoring.php
 * (role name == "super admin", case-insensitive).
 *
 * @return int the validated staff_id
 */
function sm_require_super_admin($mysqli, $body) {
    $staff_id = isset($body['caller_staff_id']) ? (int) $body['caller_staff_id'] : 0;
    if ($staff_id < 1) {
        sm_json_out(['success' => false, 'error' => 'Smart Monitoring is restricted to Super Admin.']);
    }
    $sql = "SELECT LOWER(TRIM(r.name)) AS role_name
            FROM staff_roles sr
            INNER JOIN roles r ON r.id = sr.role_id
            WHERE sr.staff_id = $staff_id";
    $res = $mysqli->query($sql);
    if (!$res) {
        sm_json_out(['success' => false, 'error' => 'Role lookup failed: ' . $mysqli->error]);
    }
    $is_super = false;
    while ($row = $res->fetch_assoc()) {
        if ((string) ($row['role_name'] ?? '') === 'super admin') {
            $is_super = true;
            break;
        }
    }
    if (!$is_super) {
        sm_json_out(['success' => false, 'error' => 'Smart Monitoring is restricted to Super Admin.']);
    }
    return $staff_id;
}

/**
 * Does the snapshots table exist? Mirrors Monitoring_model::table_exists().
 */
function sm_snapshots_table_exists($mysqli) {
    $res = $mysqli->query("SHOW TABLES LIKE 'student_monitoring_snapshots'");
    if (!$res) {
        return false;
    }
    $exists = $res->num_rows > 0;
    $res->free();
    return $exists;
}

/**
 * Decode a JSON column to an associative array; returns [] when blank/invalid.
 */
function sm_decode_json($raw) {
    if ($raw === null || $raw === '') {
        return [];
    }
    $d = json_decode((string) $raw, true);
    return is_array($d) ? $d : [];
}

/**
 * Decode a JSON suggestions column (array of strings).
 *
 * @return array<int, string>
 */
function sm_decode_suggestions($raw) {
    $d = sm_decode_json($raw);
    $out = [];
    foreach ($d as $line) {
        $s = trim((string) $line);
        if ($s !== '') {
            $out[] = $s;
        }
    }
    return $out;
}
