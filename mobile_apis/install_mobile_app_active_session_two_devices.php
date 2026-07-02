<?php
/**
 * Migrate mobile_app_active_session to allow two concurrent devices per account.
 *
 * URL:
 *   GET /mobile_apis/install_mobile_app_active_session_two_devices.php?install_key=YOUR_KEY&format=html
 */

require_once __DIR__ . '/pl_install_helper.php';

pl_install_require_secret();

$format = isset($_GET['format']) ? strtolower(trim((string) $_GET['format'])) : 'json';

$mysqli = pl_mysqli_connect();
$steps  = array();

if (!pl_mobile_app_session_table_exists($mysqli)) {
    $create = pl_install_run_sql_file(__DIR__ . '/mobile_app_active_session.sql');
    $mysqli->close();
    if ($format === 'html') {
        pl_install_html_response($create, 'install_mobile_app_active_session_two_devices');
    }
    pl_install_json_response($create);
}

$alter_path = __DIR__ . '/mobile_app_active_session_allow_two_devices.sql';
$raw        = file_get_contents($alter_path);
$statements = array_filter(array_map('trim', explode(';', pl_install_strip_sql_comments($raw))));

foreach ($statements as $sql) {
    if ($sql === '') {
        continue;
    }
    $ok = $mysqli->query($sql);
    $steps[] = array(
        'success' => (bool) $ok,
        'sql'     => $sql,
        'error'   => $ok ? null : $mysqli->error,
    );
}

$mysqli->close();

$all_ok = true;
foreach ($steps as $step) {
    if (empty($step['success'])) {
        $all_ok = false;
        break;
    }
}

$result = array(
    'success' => $all_ok,
    'message' => $all_ok
        ? 'mobile_app_active_session now supports up to 2 concurrent devices per account.'
        : 'One or more migration steps failed.',
    'steps'   => $steps,
);

if ($format === 'html') {
    pl_install_html_response($result, 'install_mobile_app_active_session_two_devices');
}

pl_install_json_response($result);
