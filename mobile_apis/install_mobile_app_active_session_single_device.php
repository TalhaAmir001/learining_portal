<?php
/**
 * Revert mobile_app_active_session to one session per account.
 *
 * URL:
 *   GET /mobile_apis/install_mobile_app_active_session_single_device.php?install_key=YOUR_KEY&format=html
 */

require_once __DIR__ . '/pl_install_helper.php';

pl_install_require_secret();

$format = isset($_GET['format']) ? strtolower(trim((string) $_GET['format'])) : 'json';

$mysqli = pl_mysqli_connect();

if (!pl_mobile_app_session_table_exists($mysqli)) {
    $create = pl_install_run_sql_file(__DIR__ . '/mobile_app_active_session.sql');
    $mysqli->close();
    if ($format === 'html') {
        pl_install_html_response($create, 'install_mobile_app_active_session_single_device');
    }
    pl_install_json_response($create);
}

$alter_path = __DIR__ . '/mobile_app_active_session_revert_single_device.sql';
$raw        = file_get_contents($alter_path);
$statements = array_filter(array_map('trim', explode(';', pl_install_strip_sql_comments($raw))));

$steps = array();
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
        ? 'mobile_app_active_session reverted to one session per account.'
        : 'One or more migration steps failed (index may already be correct).',
    'steps'   => $steps,
);

if ($format === 'html') {
    pl_install_html_response($result, 'install_mobile_app_active_session_single_device');
}

pl_install_json_response($result);
